#!/usr/bin/env bash
# =============================================================================
# optimize.sh — Aplica os ajustes de sistema (não-visuais) que fazem este
# Kali Linux rodar do jeito que roda: boot mais rápido, driver de vídeo são,
# disco sem lixo acumulado, serviços redundantes desligados.
#
# Isso é complementar ao install.sh (que cuida do rice: i3/polybar/kitty/zsh).
# Rode install.sh primeiro, depois este.
#
# O que este script faz (cada bloco checa se se aplica antes de mexer):
#   1. Corrige o driver NVIDIA se o symlink do GLX estiver quebrado (causa
#      clássica de janelas com conteúdo invisível em apps que usam OpenGL)
#   2. Protege pacotes críticos (glx-alternative-*, nvidia-smi) e remove
#      kernels/dependências órfãs com autoremove
#   3. Limpa cache do apt e do journal do systemd, e põe um teto persistente
#      (500M) pro journal não crescer sem limite de novo
#   4. Desabilita NetworkManager-wait-online e o networking.service legado
#      quando o NetworkManager já cuida da rede sozinho (evita ~5-6s de boot
#      esperando à toa)
#   5. Coloca o Docker em ativação por socket (sobe sob demanda em vez de
#      sempre no boot) — só se o Docker estiver instalado
#   6. Desabilita fwupd-refresh.timer se o fwupd estiver instalado e você
#      não usar atualização de firmware por ele
#   7. Garante fstrim.timer ativo e o scheduler de I/O em "none" (deixa o
#      NVMe cuidar da própria fila) se o disco raiz for SSD/NVMe
#   8. Garante "noatime" no mount da raiz (fstab) — evita escritas de
#      metadado a cada leitura de arquivo
#   9. Ajusta vm.swappiness para 10 e vm.vfs_cache_pressure para 50 em
#      máquinas com 8GB+ de RAM (retém cache de metadado de arquivos por
#      mais tempo, útil com muitos arquivos pequenos — notas, wordlists, etc.)
#  10. Reduz o tempo de espera do menu do GRUB (GRUB_TIMEOUT) se estiver
#      maior que 3s — não remove nenhuma entrada de boot, só o tempo de
#      espera antes de escolher a padrão
#  11. Oferece (com confirmação, não roda sozinho) desativar a checagem de
#      resume-de-hibernação no initramfs — só vale se você nunca hiberna;
#      pode custar ~200s de boot travado silenciosamente se o dispositivo de
#      resume não responder rápido
#
# Cada etapa é idempotente e segura de rodar de novo. Nada aqui mexe em
# tema, cores, gaps ou qualquer coisa cosmética do i3/polybar/kitty.
#
# Uso:
#   ./optimize.sh            # aplica tudo (pede sua senha sudo quando necessário)
#   ./optimize.sh --dry-run  # mostra o que seria feito, sem executar
# =============================================================================

set -uo pipefail

DRY_RUN=0
[[ "${1:-}" == "--dry-run" ]] && DRY_RUN=1

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; BOLD='\033[1m'; NC='\033[0m'
info()  { echo -e "${GREEN}[✓]${NC} $1"; }
warn()  { echo -e "${YELLOW}[!]${NC} $1"; }
error() { echo -e "${RED}[✗]${NC} $1"; }
step()  { echo -e "\n${BOLD}${GREEN}═══ $1 ═══${NC}\n"; }
run()   { if [[ $DRY_RUN -eq 1 ]]; then echo "+ $*"; else eval "$@"; fi; }

if [[ $EUID -eq 0 ]]; then
  error "Não rode como root. Rode como o usuário normal (o script usa sudo quando precisa)."
  exit 1
fi

if ! sudo -n true 2>/dev/null; then
  warn "Este script precisa de sudo para vários passos."
  warn "Rode 'sudo -v' antes se quiser evitar prompts de senha no meio do processo."
fi

step "1/11 — Driver NVIDIA: checando módulo GLX"

if lspci -k 2>/dev/null | grep -qi "nvidia"; then
  GLX_LINK="/usr/lib/xorg/modules/extensions/libglxserver_nvidia.so"
  if [[ -e "$GLX_LINK" ]]; then
    info "Symlink do GLX da NVIDIA presente, driver OK"
  else
    warn "Symlink do GLX da NVIDIA ausente (causa clássica de janelas com"
    warn "conteúdo invisível em apps OpenGL/Electron). Reinstalando o pacote"
    warn "do driver Xorg para recriar o symlink..."
    run "sudo apt install --reinstall -y xserver-xorg-video-nvidia"
    if [[ -e "$GLX_LINK" || $DRY_RUN -eq 1 ]]; then
      info "Symlink recriado. É necessário 'sudo reboot' para o X recarregar o driver."
    else
      error "Symlink ainda ausente após reinstalar — pode precisar de 'sudo apt install --reinstall -y nvidia-driver'"
    fi
  fi
else
  info "Sem GPU NVIDIA detectada, pulando"
fi

step "2/11 — Limpeza de pacotes: protegendo críticos e removendo órfãos"

PROTECT_PKGS=()
for p in nvidia-smi seclists update-glx glx-alternative-nvidia glx-diversions glx-alternative-mesa; do
  dpkg -s "$p" &>/dev/null && PROTECT_PKGS+=("$p")
done
if [[ ${#PROTECT_PKGS[@]} -gt 0 ]]; then
  run "sudo apt-mark manual ${PROTECT_PKGS[*]}"
  info "Protegidos contra autoremove: ${PROTECT_PKGS[*]}"
fi
run "sudo apt-get autoremove -y"
info "Kernels/dependências órfãs removidos"

step "3/11 — Cache do apt e do journal"

run "sudo apt clean"
run "sudo journalctl --vacuum-time=7d"
info "apt clean + journal podado (mantendo últimos 7 dias)"

if ! grep -q "^SystemMaxUse=" /etc/systemd/journald.conf 2>/dev/null; then
  run "sudo sed -i 's/^#\\?SystemMaxUse=.*/SystemMaxUse=500M/' /etc/systemd/journald.conf"
  run "grep -q '^SystemMaxUse=' /etc/systemd/journald.conf || echo 'SystemMaxUse=500M' | sudo tee -a /etc/systemd/journald.conf >/dev/null"
  run "sudo systemctl restart systemd-journald"
  info "Teto persistente de 500M configurado no journald (não volta a crescer sem limite)"
else
  info "journald já tem SystemMaxUse configurado, mantendo"
fi

step "4/11 — Serviços de rede redundantes"

if systemctl is-active --quiet NetworkManager && systemctl list-unit-files NetworkManager-wait-online.service &>/dev/null; then
  run "sudo systemctl disable NetworkManager-wait-online.service"
  info "NetworkManager-wait-online.service desabilitado (~5s de boot economizados)"
fi

if systemctl list-unit-files networking.service &>/dev/null && systemctl is-enabled --quiet networking.service 2>/dev/null; then
  if systemctl is-active --quiet NetworkManager; then
    run "sudo systemctl disable networking.service"
    info "networking.service (ifupdown legado) desabilitado — NetworkManager já cuida da rede"
  fi
else
  info "networking.service não presente/já desabilitado, nada a fazer"
fi

step "5/11 — Docker sob demanda"

if command -v docker &>/dev/null && systemctl list-unit-files docker.service &>/dev/null; then
  run "sudo systemctl enable docker.socket"
  run "sudo systemctl disable docker.service"
  info "Docker configurado para subir sob demanda (via docker.socket) em vez de todo boot"
else
  info "Docker não instalado, pulando"
fi

step "6/11 — fwupd-refresh (checagem de firmware)"

if systemctl list-unit-files fwupd-refresh.timer &>/dev/null; then
  read -r -p "Você usa atualização de firmware via fwupd/fwupdmgr? [y/N] " ans
  if [[ ! "$ans" =~ ^[Yy]$ ]]; then
    run "sudo systemctl disable fwupd-refresh.timer"
    info "fwupd-refresh.timer desabilitado"
  else
    info "Mantendo fwupd-refresh.timer habilitado"
  fi
else
  info "fwupd não instalado, pulando"
fi

step "7/11 — TRIM e scheduler de I/O do SSD"

ROOT_DEV="$(lsblk -no pkname "$(findmnt -no SOURCE /)" 2>/dev/null | head -1)"
if [[ -n "$ROOT_DEV" ]] && [[ "$(cat /sys/block/"$ROOT_DEV"/queue/rotational 2>/dev/null)" == "0" ]]; then
  run "sudo systemctl enable --now fstrim.timer"
  info "fstrim.timer ativo (disco raiz é SSD)"

  CUR_SCHED="$(cat /sys/block/"$ROOT_DEV"/queue/scheduler 2>/dev/null | grep -oP '\[\K[^\]]+')"
  if [[ "$CUR_SCHED" == "none" ]]; then
    info "Scheduler de I/O já é 'none' (ideal para NVMe, que já tem fila própria)"
  else
    UDEV_RULE="/etc/udev/rules.d/60-ioscheduler.rules"
    run "echo 'ACTION==\"add|change\", KERNEL==\"nvme[0-9]n[0-9]\", ATTR{queue/scheduler}=\"none\"' | sudo tee '$UDEV_RULE' >/dev/null"
    run "sudo udevadm control --reload-rules && sudo udevadm trigger --subsystem-match=block"
    info "Scheduler de I/O do NVMe fixado em 'none' via udev (persiste entre boots)"
  fi
else
  info "Disco raiz não parece ser SSD (ou não detectado), pulando TRIM/scheduler"
fi

step "8/11 — noatime no mount da raiz"

ROOT_OPTS="$(findmnt -no OPTIONS / 2>/dev/null)"
if [[ "$ROOT_OPTS" == *noatime* || "$ROOT_OPTS" == *relatime* ]]; then
  info "Mount da raiz já usa noatime/relatime, nada a fazer"
elif [[ -f /etc/fstab ]] && grep -qE '^\S+\s+/\s' /etc/fstab; then
  run "sudo cp /etc/fstab /etc/fstab.bak.\$(date +%Y%m%d%H%M%S)"
  run "sudo sed -i -E '/\\s\\/\\s/ s/(defaults|errors=[^, ]+)/\\1,noatime/' /etc/fstab"
  warn "fstab atualizado com noatime (backup salvo como fstab.bak.<timestamp>). Aplica no próximo boot."
else
  warn "Não achei a linha da raiz no /etc/fstab automaticamente — pulei por segurança, ajuste manual se quiser"
fi

step "9/11 — Swappiness e cache de metadados (vfs_cache_pressure)"

MEM_KB=$(awk '/MemTotal/{print $2}' /proc/meminfo)
if [[ "$MEM_KB" -ge 8000000 ]]; then
  run "printf 'vm.swappiness=10\\nvm.vfs_cache_pressure=50\\n' | sudo tee /etc/sysctl.d/99-swappiness.conf >/dev/null"
  run "sudo sysctl -p /etc/sysctl.d/99-swappiness.conf >/dev/null"
  info "vm.swappiness=10 e vm.vfs_cache_pressure=50 (máquina tem $(( MEM_KB / 1024 / 1024 ))GB+ de RAM)"
else
  info "Menos de 8GB de RAM, mantendo valores padrão do kernel"
fi

step "10/11 — Tempo de espera do menu do GRUB"

if [[ -f /etc/default/grub ]]; then
  CUR_TIMEOUT="$(grep -oP '^GRUB_TIMEOUT=\K[0-9]+' /etc/default/grub || echo "")"
  if [[ -n "$CUR_TIMEOUT" && "$CUR_TIMEOUT" -gt 3 ]]; then
    run "sudo sed -i 's/^GRUB_TIMEOUT=.*/GRUB_TIMEOUT=2/' /etc/default/grub"
    run "sudo update-grub"
    info "GRUB_TIMEOUT reduzido de ${CUR_TIMEOUT}s para 2s (nenhuma entrada de boot foi removida)"
  else
    info "GRUB_TIMEOUT já é baixo (${CUR_TIMEOUT:-desconhecido}s), nada a fazer"
  fi
else
  info "GRUB não encontrado em /etc/default/grub (outro bootloader?), pulando"
fi

step "11/11 — Resume de hibernação (opcional, pode economizar ~200s de boot)"

RESUME_CONF="/etc/initramfs-tools/conf.d/resume"
if [[ -f "$RESUME_CONF" ]] && ! grep -q "^RESUME=none" "$RESUME_CONF"; then
  warn "Se o dispositivo configurado para RESUME não responder rápido no boot,"
  warn "o initramfs pode travar em silêncio por ~200s esperando por ele."
  read -r -p "Você usa hibernação (suspender pro disco)? [y/N] " ans
  if [[ ! "$ans" =~ ^[Yy]$ ]]; then
    run "echo 'RESUME=none' | sudo tee '$RESUME_CONF' >/dev/null"
    run "sudo update-initramfs -u -k all"
    info "Checagem de resume desativada"
  else
    info "Mantendo checagem de resume (você usa hibernação)"
  fi
else
  info "Já configurado ou não aplicável, pulando"
fi

echo ""
echo -e "${BOLD}${GREEN}══════════════════════════════════════════════════${NC}"
echo -e "${BOLD}${GREEN}  Otimização completa!${NC}"
echo -e "${BOLD}${GREEN}══════════════════════════════════════════════════${NC}"
echo ""
echo -e "  Se o passo 1/11 reinstalou o driver NVIDIA, reinicie para aplicar:"
echo -e "    ${BOLD}sudo reboot${NC}"
echo ""

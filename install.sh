#!/usr/bin/env bash
# =============================================================================
# install.sh — Reproduz o ambiente desktop (i3 + polybar + kitty + zsh) deste
# Kali Linux em qualquer Kali Linux "pelado" (limpo).
#
# Barra ativa: polybar, tema "Kali Dragon" (config/polybar/kali). O eww
# (barra original) também é instalado/compilado e fica disponível como
# fallback — ver README.md.
#
# O que este script faz:
#   1. Instala pacotes apt necessários (i3, polybar, eww deps, picom, dunst,
#      rofi, kitty, zsh, ferramentas de tema, etc.)
#   2. Compila e instala o eww (bar de fallback) a partir do código-fonte
#      (não está nos repositórios do Kali)
#   3. Baixa o binário do greenclip (gerenciador de clipboard)
#   4. Instala o autotiling via pip
#   5. Instala o atuin (histórico de shell com busca fuzzy, usado no .zshrc)
#   6. Instala oh-my-zsh + powerlevel10k + plugins de zsh
#   7. Copia todas as configs (~/.config/*, dotfiles) e fontes Nerd Font
#   8. Compila/instala o tema GTK kizus_phocus e o icon theme zafiro-icon-theme
#      (o cursor "macOS Cursor Set" não tem instalação automatizável — ver
#      aviso impresso nesta etapa e o README)
#   9. Define zsh como shell padrão
#
# Depois de rodar este script, rode também o optimize.sh (mesma pasta) para
# aplicar os ajustes de sistema (boot, serviços, disco, driver de vídeo) que
# fazem este Kali rodar do jeito que roda — ver README.md.
#
# Uso:
#   ./install.sh            # instala tudo
#   ./install.sh --dry-run  # mostra o que seria feito, sem executar
#
# Idempotente: pode ser rodado mais de uma vez. Configs existentes no
# destino são movidas para *.bak.<timestamp> antes de serem sobrescritas.
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
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

step "1/10 — Pacotes apt"

APT_PKGS=(
  # WM / X11 core
  i3-wm i3lock xorg xserver-xorg lightdm dex xdotool xdg-desktop-portal
  x11-xserver-utils
  # bar / compositor / notifications / launcher / clipboard
  polybar picom dunst rofi
  # terminal / shell
  kitty zsh
  # eww build deps (eww não está nos repositórios do Kali)
  build-essential pkg-config libgtk-3-dev libcairo2-dev libpango1.0-dev \
  libglib2.0-dev libgtk-layer-shell-dev libdbusmenu-gtk3-dev
  # utilitários usados no config
  feh flameshot redshift xclip jq network-manager-gnome openrgb \
  pavucontrol lxpolkit policykit-1-gnome playerctl lm-sensors dolphin \
  autokey-gtk qt5ct qt6ct qt5-style-kvantum papirus-icon-theme \
  fonts-jetbrains-mono
  # git/curl/build tooling
  git curl wget python3-pip pipx
  # build deps do tema GTK kizus_phocus (compila com npm/sass)
  nodejs npm
)

run "sudo apt update"
run "sudo apt install -y ${APT_PKGS[*]}"
info "Pacotes apt instalados"

step "2/10 — Rust/Cargo (necessário para compilar o eww)"

if ! command -v cargo &>/dev/null; then
  warn "Cargo não encontrado, instalando Rust via rustup..."
  run "curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y"
  # shellcheck disable=SC1091
  source "$HOME/.cargo/env" 2>/dev/null || true
  info "Rust instalado"
else
  info "Cargo já presente: $(cargo --version)"
fi

step "3/10 — Compilando e instalando o eww"

if command -v eww &>/dev/null; then
  info "eww já instalado ($(eww --version 2>/dev/null)), pulando build"
else
  TMPDIR=$(mktemp -d)
  run "git clone --depth 1 https://github.com/elkowar/eww.git '$TMPDIR/eww'"
  run "(cd '$TMPDIR/eww' && cargo build --release --no-default-features --features x11)"
  run "sudo cp '$TMPDIR/eww/target/release/eww' /usr/local/bin/eww"
  run "sudo chmod +x /usr/local/bin/eww"
  run "rm -rf '$TMPDIR'"
  info "eww compilado e instalado em /usr/local/bin/eww"
fi

step "4/10 — Instalando greenclip (gerenciador de clipboard)"

if command -v greenclip &>/dev/null; then
  info "greenclip já instalado, pulando"
else
  GC_URL="https://github.com/erebe/greenclip/releases/latest/download/greenclip"
  run "sudo curl -fsSL '$GC_URL' -o /usr/local/bin/greenclip"
  run "sudo chmod +x /usr/local/bin/greenclip"
  info "greenclip instalado em /usr/local/bin/greenclip"
fi

step "5/10 — Instalando autotiling"

run "pip3 install --user --break-system-packages autotiling || pipx install autotiling"
info "autotiling instalado em ~/.local/bin"

step "6/10 — Atuin (histórico de shell com busca fuzzy)"

if command -v atuin &>/dev/null || [[ -x "$HOME/.atuin/bin/atuin" ]]; then
  info "atuin já instalado, pulando"
else
  run "curl --proto '=https' --tlsv1.2 -sSf https://setup.atuin.sh | bash"
  info "atuin instalado em ~/.atuin/bin"
fi

step "7/10 — oh-my-zsh + powerlevel10k + plugins"

if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
  run "RUNZSH=no CHSH=no KEEP_ZSHRC=yes sh -c \"\$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)\""
  info "oh-my-zsh instalado"
else
  info "oh-my-zsh já presente"
fi

ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
if [[ ! -d "$ZSH_CUSTOM/themes/powerlevel10k" ]]; then
  run "git clone --depth 1 https://github.com/romkatv/powerlevel10k.git '$ZSH_CUSTOM/themes/powerlevel10k'"
fi
run "mkdir -p '$HOME/.zsh/plugins'"
if [[ ! -d "$HOME/.zsh/plugins/zsh-autosuggestions" ]]; then
  run "git clone --depth 1 https://github.com/zsh-users/zsh-autosuggestions '$HOME/.zsh/plugins/zsh-autosuggestions'"
fi
if [[ ! -d "$HOME/.zsh/plugins/zsh-syntax-highlighting" ]]; then
  run "git clone --depth 1 https://github.com/zsh-users/zsh-syntax-highlighting.git '$HOME/.zsh/plugins/zsh-syntax-highlighting'"
fi
info "Plugins de zsh instalados"

step "8/10 — Copiando configs, dotfiles e fontes"

backup_and_copy() {
  local src="$1" dst="$2"
  if [[ -e "$dst" && ! -L "$dst" ]]; then
    run "mv '$dst' '${dst}.bak.$(date +%Y%m%d%H%M%S)'"
  fi
  run "cp -a '$src' '$dst'"
}

run "mkdir -p '$HOME/.config'"
for d in "$SCRIPT_DIR"/config/*/; do
  name="$(basename "$d")"
  backup_and_copy "$d" "$HOME/.config/$name"
done
for f in "$SCRIPT_DIR"/config/*.{toml,list,dirs,locale,ini,conf}; do
  [[ -e "$f" ]] || continue
  name="$(basename "$f")"
  backup_and_copy "$f" "$HOME/.config/$name"
done

for f in "$SCRIPT_DIR"/home/.*; do
  name="$(basename "$f")"
  [[ "$name" == "." || "$name" == ".." ]] && continue
  backup_and_copy "$f" "$HOME/$name"
done

run "chmod +x '$HOME/.config/i3/i3status.sh' '$HOME/.config/i3/status.sh' 2>/dev/null || true"
run "chmod +x '$HOME/.config/eww/launch-eww.sh' '$HOME/.config/eww/scripts/'* 2>/dev/null || true"
run "chmod +x '$HOME/.config/polybar/launch.sh' 2>/dev/null || true"
run "find '$HOME/.config/polybar' -name '*.sh' -exec chmod +x {} + 2>/dev/null || true"

run "mkdir -p '$HOME/.local/share/fonts'"
run "cp -a '$SCRIPT_DIR'/fonts/*.ttf '$HOME/.local/share/fonts/'"
run "fc-cache -f '$HOME/.local/share/fonts' >/dev/null"
info "Fontes Nerd Font instaladas e cache atualizado"

run "sudo mkdir -p /usr/share/wallpapers/KaliTiles/contents/images"
run "sudo cp -a '$SCRIPT_DIR'/wallpapers/*.png /usr/share/wallpapers/KaliTiles/contents/images/ 2>/dev/null || true"
info "Wallpaper copiado"

step "9/10 — Tema GTK, ícones e cursor"

# kizus_phocus (fork "kizu" de janleigh/gtk3, do tema phocus)
# Fonte: https://github.com/janleigh/gtk3
if [[ -d "$HOME/.local/share/themes/kizus_phocus" ]]; then
  info "Tema kizus_phocus já instalado, pulando"
else
  TMPDIR_THEME=$(mktemp -d)
  run "git clone --depth 1 https://github.com/janleigh/gtk3.git '$TMPDIR_THEME/gtk3'"
  run "(cd '$TMPDIR_THEME/gtk3' && npm install && npm run build)"
  run "mkdir -p '$HOME/.local/share/themes/kizus_phocus'"
  run "cp -a '$TMPDIR_THEME/gtk3/index.theme' '$TMPDIR_THEME/gtk3/assets' '$TMPDIR_THEME/gtk3/dist/gtk-3.0' '$HOME/.local/share/themes/kizus_phocus/'"
  run "rm -rf '$TMPDIR_THEME'"
  info "Tema kizus_phocus instalado em ~/.local/share/themes/kizus_phocus"
fi

# zafiro-icon-theme (zayronxio/Zafiro-icons, variante Dark renomeada pra
# bater com o nome usado em config/gtk-3.0/settings.ini)
# Fonte: https://github.com/zayronxio/Zafiro-icons
if [[ -d "$HOME/.local/share/icons/zafiro-icon-theme" ]]; then
  info "Icon theme zafiro-icon-theme já instalado, pulando"
else
  TMPDIR_ICONS=$(mktemp -d)
  run "git clone --depth 1 https://github.com/zayronxio/Zafiro-icons.git '$TMPDIR_ICONS/zafiro'"
  run "mkdir -p '$HOME/.local/share/icons'"
  run "cp -a '$TMPDIR_ICONS/zafiro/Dark' '$HOME/.local/share/icons/zafiro-icon-theme'"
  run "rm -rf '$TMPDIR_ICONS'"
  run "gtk-update-icon-cache -f -t '$HOME/.local/share/icons/zafiro-icon-theme' 2>/dev/null || true"
  info "Icon theme zafiro-icon-theme instalado em ~/.local/share/icons/zafiro-icon-theme"
fi

# "macOS Cursor Set" (gnome-look.org) NÃO tem instalação automatizável: o
# site (pling/gnome-look) não oferece link de download direto nem API
# estável (a antiga API OCS retorna 410 Gone) — só dá pra baixar clicando
# na página. Instale manualmente:
if [[ -d "$HOME/.icons/macOS Cursor Set" || -d "$HOME/.local/share/icons/macOS Cursor Set" ]]; then
  info "Cursor 'macOS Cursor Set' já presente, pulando"
else
  warn "Cursor 'macOS Cursor Set' precisa ser instalado manualmente:"
  warn "  1. Baixe em https://www.gnome-look.org/p/1148748/ (botão de download da página)"
  warn "  2. Extraia o .tar.gz/.zip"
  warn "  3. Copie a pasta extraída para ~/.icons/ (crie se não existir)"
  warn "  4. Confira se o nome da pasta bate com 'macOS Cursor Set' em"
  warn "     config/gtk-3.0/settings.ini — renomeie a pasta se for diferente"
fi

step "10/10 — Shell padrão"

if [[ "$SHELL" != *zsh ]]; then
  run "sudo chsh -s \"\$(command -v zsh)\" \"\$USER\""
  info "Shell padrão alterado para zsh (relogue para aplicar)"
else
  info "zsh já é o shell padrão"
fi

echo ""
echo -e "${BOLD}${GREEN}══════════════════════════════════════════════════${NC}"
echo -e "${BOLD}${GREEN}  Instalação completa!${NC}"
echo -e "${BOLD}${GREEN}══════════════════════════════════════════════════${NC}"
echo ""
echo -e "  Próximos passos:"
echo -e "    1. Faça logout e escolha a sessão ${BOLD}i3${NC} no LightDM"
echo -e "    2. No primeiro login, rode ${BOLD}p10k configure${NC} se quiser reconfigurar o prompt"
echo -e "       (o ~/.p10k.zsh copiado já traz a config original)"
echo -e "    3. Atalhos principais (mod = Super):"
echo -e "         mod+t        abrir kitty"
echo -e "         mod+a        rofi (drun/run)"
echo -e "         mod+v        rofi clipboard (greenclip)"
echo -e "         mod+q        fechar janela"
echo -e "         mod+setas    focar janelas"
echo -e "         mod+shift+setas  mover janelas"
echo -e "         mod+1..0     trocar workspace"
echo -e "         mod+f        fullscreen"
echo -e "         mod+shift+space  floating toggle"
echo -e "         mod+r        modo resize"
echo -e "         mod+p / Print   flameshot gui (screenshot)"
echo -e "         mod+shift+c  reload i3   |   mod+shift+r  restart i3"
echo ""

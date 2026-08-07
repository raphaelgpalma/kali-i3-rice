# kali-i3-rice

Ambiente desktop deste Kali Linux (i3 + polybar + kitty + zsh), empacotado para
reinstalar em qualquer Kali Linux limpo.

## O que é este sistema

- **Sessão**: X11, LightDM, sessão `i3` (`XDG_CURRENT_DESKTOP=i3`)
- **Window manager**: i3wm 4.25, com `autotiling` para split automático
- **Barra**: polybar, tema custom "Kali Dragon" (`config/polybar/kali`) — flutuante,
  fundo translúcido, cores oficiais do Kali Linux. Ativada no `i3/config` via
  `~/.config/polybar/kali/launch.sh`.
  - [eww](https://github.com/elkowar/eww) (widget `bar` em `config/eww`) foi a barra
    original e continua disponível como fallback: comente a linha do polybar e
    descomente a do eww em `config/i3/config`, depois `mod+shift+r` — ou rode
    `~/.config/polybar/kali/revert.sh` pra trocar na hora sem reiniciar o i3.
  - Outros 10+ temas de polybar em `config/polybar` (não ativos, apenas disponíveis).
- **Compositor**: picom (sombras desativadas, fade + cantos arredondados)
- **Notificações**: dunst
- **Launcher**: rofi (drun/run + clipboard via greenclip)
- **Terminal**: kitty, fonte JetBrainsMono Nerd Font, tema Floraverse
- **Shell**: zsh + oh-my-zsh + powerlevel10k + zsh-autosuggestions + zsh-syntax-highlighting
- **Histórico de shell**: [atuin](https://atuin.sh) (busca fuzzy, `Ctrl+R`)
- **Clipboard manager**: greenclip
- **Screenshot**: flameshot (`mod+p` / `Print`)
- **Cor de tela / redshift**: `mod+shift+n` liga, `mod+shift+m` desliga
- **GTK**: tema `kizus_phocus` + ícones `zafiro-icon-theme` + cursor `macOS Cursor Set`
  (tema/ícones/cursor customizados não estão nos repositórios do Kali — ver nota abaixo)
- **Qt**: qt5ct com paleta Kali-Dark + ícones Flat-Remix-Blue-Dark

## Atalhos principais (mod = Super/Mod4)

| Atalho | Ação |
|---|---|
| `mod+t` | abrir kitty |
| `mod+a` | rofi (drun/run) |
| `mod+v` | rofi clipboard (greenclip) |
| `mod+e` | abrir dolphin |
| `mod+q` | fechar janela |
| `mod+setas` | focar janela |
| `mod+shift+setas` | mover janela |
| `mod+1..0` | ir para workspace |
| `mod+shift+1..0` | mover janela para workspace |
| `ctrl+mod+setas` | workspace seguinte/anterior |
| `mod+b` / `mod+shift+v` | split horizontal/vertical |
| `mod+f` | fullscreen |
| `mod+shift+space` | floating toggle |
| `mod+r` | modo resize (setas para redimensionar, Enter/Esc sai) |
| `mod+shift+c` | reload i3 |
| `mod+shift+r` | restart i3 |
| `mod+p` / `Print` | flameshot gui |
| `XF86Audio*` | volume/mute |
| `mod+shift+n` / `mod+shift+m` | redshift on/off |

## Instalação num Kali limpo

```bash
git clone <este repo> kali-i3-rice   # ou copie a pasta
cd kali-i3-rice
./install.sh               # instala o rice: pacotes, eww, greenclip, autotiling,
                            # atuin, oh-my-zsh/p10k/plugins, configs, fontes
./optimize.sh               # aplica os ajustes de sistema (boot, driver, disco)
./install.sh   --dry-run    # qualquer um dos dois aceita --dry-run pra só
./optimize.sh --dry-run     # mostrar o que seria feito, sem executar nada
```

`install.sh` instala pacotes apt, compila o eww do zero (não está no
repositório do Kali), baixa o binário do greenclip, instala autotiling via
pip, instala o atuin, instala oh-my-zsh/powerlevel10k/plugins, copia todas as
configs e fontes, e define zsh como shell padrão. Configs existentes no
destino são renomeadas para `*.bak.<timestamp>` antes de serem sobrescritas —
nada é apagado.

`optimize.sh` é o que faz esse Kali rodar do jeito que roda por baixo do
capô — sem ele o rice fica bonito mas continua com o boot lento e o lixo de
sistema padrão. Ele:

- Corrige o driver NVIDIA se o symlink do GLX estiver quebrado (causa clássica
  de janelas com conteúdo invisível em apps OpenGL/Electron) — só roda se
  detectar uma GPU NVIDIA.
- Protege pacotes críticos (`glx-alternative-*`, `nvidia-smi`) antes de rodar
  `autoremove`, pra não levar o driver de vídeo junto na faxina.
- Limpa cache do apt e journal do systemd (mantém últimos 7 dias) e configura
  um teto persistente de 500M pro journal não voltar a crescer sem limite.
- Desabilita `NetworkManager-wait-online` e o `networking.service` legado
  quando o NetworkManager já cuida da rede sozinho.
- Põe o Docker pra subir sob demanda (via `docker.socket`) em vez de todo
  boot — só se o Docker estiver instalado.
- Pergunta se você usa fwupd/hibernação antes de desabilitar essas checagens
  (a de hibernação, se mal configurada, pode travar o boot em silêncio por
  ~200 segundos).
- Garante `fstrim.timer` ativo e o scheduler de I/O do NVMe em `none` (deixa
  o próprio SSD gerenciar a fila, que já é otimizada pra isso).
- Garante `noatime` no mount da raiz (com backup do fstab antes de tocar nele).
- Ajusta `vm.swappiness` para 10 e `vm.vfs_cache_pressure` para 50 em máquinas
  com 8GB+ de RAM — mantém cache de metadado de arquivos por mais tempo,
  o que ajuda quando há muitos arquivos pequenos (notas, wordlists, repos).
- Reduz o `GRUB_TIMEOUT` pra 2s se estiver maior que 3s — não remove nenhuma
  entrada de boot, só encurta a espera antes de escolher a padrão.

Nenhum dos dois scripts mexe em tema, cores, gaps ou qualquer coisa
cosmética — isso é 100% dos arquivos em `config/` e `home/`.

Depois de rodar os dois, faça logout e selecione a sessão **i3** na tela de
login. Se o `optimize.sh` tiver reinstalado o driver NVIDIA, dê `sudo reboot`
antes.

## O que NÃO está incluído (fora do escopo de "rice")

- Tema GTK `kizus_phocus`, ícones `zafiro-icon-theme` e cursor `macOS Cursor
  Set` — não são pacotes apt padrão do Kali nem têm fonte automatizável de
  forma confiável; instale manualmente se quiser o visual 100% idêntico.
- Aplicativos pesados (BloodHound, ferramentas de pentest, wordlists, etc.) —
  isso é ambiente de trabalho, não "rice" de desktop.
- `~/.zsh_history`, `~/.bash_history`, credenciais, chaves — nada sensível é
  copiado.

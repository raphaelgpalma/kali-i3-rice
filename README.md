# kali-i3-rice

Ambiente desktop deste Kali Linux (i3 + eww + kitty + zsh), empacotado para
reinstalar em qualquer Kali Linux limpo.

## O que é este sistema

- **Sessão**: X11, LightDM, sessão `i3` (`XDG_CURRENT_DESKTOP=i3`)
- **Window manager**: i3wm 4.25, com `autotiling` para split automático
- **Barra**: [eww](https://github.com/elkowar/eww) (widget `bar` em `config/eww`) —
  não polybar, apesar de o polybar estar instalado e configurado como alternativa
  (10+ temas em `config/polybar`, nenhum ativo por padrão)
- **Compositor**: picom (sombras desativadas, fade + cantos arredondados)
- **Notificações**: dunst
- **Launcher**: rofi (drun/run + clipboard via greenclip)
- **Terminal**: kitty, fonte JetBrainsMono Nerd Font, tema Floraverse
- **Shell**: zsh + oh-my-zsh + powerlevel10k + zsh-autosuggestions + zsh-syntax-highlighting
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
./install.sh              # instala tudo
./install.sh --dry-run    # só mostra o que seria feito
```

O script instala pacotes apt, compila o eww do zero (não está no repositório
do Kali), baixa o binário do greenclip, instala autotiling via pip, instala
oh-my-zsh/powerlevel10k/plugins, copia todas as configs e fontes, e define
zsh como shell padrão. Configs existentes no destino são renomeadas para
`*.bak.<timestamp>` antes de serem sobrescritas — nada é apagado.

Depois de rodar, faça logout e selecione a sessão **i3** na tela de login.

## O que NÃO está incluído (fora do escopo de "rice")

- Tema GTK `kizus_phocus`, ícones `zafiro-icon-theme` e cursor `macOS Cursor
  Set` — não são pacotes apt padrão do Kali nem têm fonte automatizável de
  forma confiável; instale manualmente se quiser o visual 100% idêntico.
- Aplicativos pesados (BloodHound, ferramentas de pentest, wordlists, etc.) —
  isso é ambiente de trabalho, não "rice" de desktop.
- `~/.zsh_history`, `~/.bash_history`, credenciais, chaves — nada sensível é
  copiado.

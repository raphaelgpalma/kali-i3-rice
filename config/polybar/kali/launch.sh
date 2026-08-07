#!/usr/bin/env bash
# Liga a barra Polybar "Kali Dragon" no lugar da eww, SEM tocar no
# ~/.config/i3/config. Como o i3 config continua chamando o eww via
# exec_always, basta dar mod+shift+r (restart do i3) para voltar pra eww.

set -e
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# compositor precisa estar rodando pra transparência real da barra
if ! pgrep -x picom >/dev/null; then
  # picom.conf não define backend (picom >=10 exige um); passamos via CLI
  # em vez de editar o arquivo de config existente.
  picom --config ~/.config/picom/picom.conf --backend xrender -b
  sleep 0.3
fi

eww kill 2>/dev/null || true
killall -q polybar 2>/dev/null || true
while pgrep -u "$UID" -x polybar >/dev/null; do sleep 0.2; done

polybar -q kali -c "$DIR/config.ini" &
disown

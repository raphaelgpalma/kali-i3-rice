#!/usr/bin/env bash
# Reverte manualmente pra eww sem precisar reiniciar o i3
killall -q polybar 2>/dev/null || true
~/.config/eww/launch-eww.sh

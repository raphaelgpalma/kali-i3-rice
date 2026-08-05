#!/usr/bin/env bash
eww kill 2>/dev/null
sleep 0.3
eww daemon &
sleep 0.5
eww open bar

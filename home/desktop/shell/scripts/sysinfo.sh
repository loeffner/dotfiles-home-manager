#!/bin/sh
# Static system info for services/SystemStats, one `key|value` per line.
echo "host|$(uname -n)"
echo "kernel|$(uname -r)"
( . /etc/os-release 2>/dev/null; echo "os|$PRETTY_NAME" )
echo "cpu|$(grep -m1 'model name' /proc/cpuinfo | cut -d: -f2- | sed 's/^ *//')"
gpu=$(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null | head -1)
[ -z "$gpu" ] && gpu=$(lspci 2>/dev/null | grep -iE 'vga|3d|display' | head -1 | sed 's/.*: //')
echo "gpu|$gpu"

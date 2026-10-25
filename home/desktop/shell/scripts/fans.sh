#!/bin/sh
# Fan access for services/Fans (Nuvoton nct6799 hwmon). The hwmon index isn't
# stable across boots, so the chip is found by name.
#   fans.sh find                    print the chip's hwmon dir (or nothing)
#   fans.sh read <hwmon>            one `idx|rpm|pwm|enable` line per PWM header
#   fans.sh enable <hwmon> <idx> <mode>   write pwmN_enable (1 = manual)
#   fans.sh set <hwmon> <idx> <pwm>       manual mode + write pwmN (0-255)
# Writes need the pwm* files group-writable (a NixOS udev rule); else no-op.
set -u
case "$1" in
  find)
    for d in /sys/class/hwmon/hwmon*; do
      if [ "$(cat "$d/name" 2>/dev/null)" = nct6799 ]; then
        echo "$d"
        break
      fi
    done
    ;;
  read)
    for p in "$2"/pwm[0-9]; do
      i=$(basename "$p" | tr -dc 0-9)
      printf '%s|%s|%s|%s\n' "$i" "$(cat "$2/fan${i}_input" 2>/dev/null)" "$(cat "$p" 2>/dev/null)" "$(cat "${p}_enable" 2>/dev/null)"
    done
    ;;
  enable)
    echo "$4" > "$2/pwm${3}_enable"
    ;;
  set)
    echo 1 > "$2/pwm${3}_enable"
    echo "$4" > "$2/pwm${3}"
    ;;
esac

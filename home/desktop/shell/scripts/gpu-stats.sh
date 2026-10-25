#!/bin/sh
# GPU usage + temperature for services/SystemStats, one `key|value` per line:
#   nv|<temp>, <util%>   NVIDIA via nvidia-smi (empty when absent / asleep)
#   amdbusy|<util%>      amdgpu busy percent from sysfs
#   amdtemp|<millideg>   amdgpu "edge" sensor from hwmon
echo "nv|$(nvidia-smi --query-gpu=temperature.gpu,utilization.gpu --format=csv,noheader,nounits 2>/dev/null | head -1)"
echo "amdbusy|$(cat /sys/class/drm/card*/device/gpu_busy_percent 2>/dev/null | head -1)"
amdtemp=
for h in /sys/class/hwmon/hwmon*; do
  [ "$(cat "$h/name" 2>/dev/null)" = amdgpu ] || continue
  for f in "$h"/temp*_input; do
    if [ "$(cat "${f%_input}_label" 2>/dev/null)" = edge ]; then
      amdtemp=$(cat "$f")
      break 2
    fi
  done
done
echo "amdtemp|$amdtemp"

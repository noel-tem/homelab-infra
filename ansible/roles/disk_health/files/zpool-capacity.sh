#!/bin/bash
# Prints each ZFS pool's size and usage as InfluxDB line protocol, for Telegraf's exec input
set -euo pipefail
command -v zpool >/dev/null || exit 0
zpool list -Hp -o name,size,alloc,free,health | while read -r name size alloc free health; do
  pct=$(awk -v a="$alloc" -v s="$size" 'BEGIN { printf "%.2f", a * 100 / s }')
  echo "zpool,pool=${name},health=${health} size=${size}i,allocated=${alloc}i,free=${free}i,used_percent=${pct}"
done

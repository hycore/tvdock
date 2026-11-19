#!/bin/bash
# 应用状态总览(冻结包/第三方包/总包数)
# 用法: tv_status.sh <电视IP>
source "$(dirname "$0")/_common.sh"
[ -z "$1" ] && { echo "用法: $0 <电视IP>"; exit 2; }
tv_gate "$1"
SER="${1}:5555"

echo "== 已收起/停用(block/suspend/disable)=="; "$ADB" -s "$SER" shell pm list packages -d 2>/dev/null | sed 's/package://' | sort
echo "== 最近一轮冻结的组件状态(读 backups/frozen_*.txt)=="
LOG=$(ls -t "$SKILL_DIR/backups/frozen_"*.txt 2>/dev/null | head -1)
if [ -n "$LOG" ]; then
  while read -r p; do
    [ -z "$p" ] && continue
    if [ -n "$("$ADB" -s "$SER" shell pm path "$p" 2>/dev/null)" ]; then
      echo "  未冻结: $p"
    else
      echo "  已冻结: $p"
    fi
  done < "$LOG"
else
  echo "  (暂无冻结记录;先运行 tv_ads_off.sh)"
fi
echo "== 第三方应用 =="; "$ADB" -s "$SER" shell pm list packages -3 2>/dev/null | sed 's/package://' | sort
echo "== 总包数 =="; "$ADB" -s "$SER" shell pm list packages 2>/dev/null | wc -l

#!/bin/bash
# ADB 保活:每 30 秒心跳 + 断线自动重连(防电视休眠断连)
# 用法: adb_keepalive.sh <电视IP>   (Ctrl+C 停止)
source "$(dirname "$0")/_common.sh"
[ -z "$1" ] && { echo "用法: $0 <电视IP>"; exit 2; }
TV_IP="$1"; SER="${TV_IP}:5555"
LOG="$SKILL_DIR/backups/keepalive_${TV_IP}.log"
mkdir -p "$(dirname "$LOG")"
echo "==== 启动 $(date '+%F %T') ====" >> "$LOG"
while true; do
  TS=$(date '+%T')
  st=$("$ADB" devices 2>/dev/null | grep "$SER" | awk '{print $2}')
  if [ "$st" = "device" ]; then
    "$ADB" -s "$SER" shell echo alive >/dev/null 2>&1 && echo "$TS 正常" >> "$LOG" || { "$ADB" disconnect "$SER" >/dev/null 2>&1; "$ADB" connect "$SER" >/dev/null 2>&1; echo "$TS 抖动重连" >> "$LOG"; }
  elif [ "$st" = "offline" ]; then
    "$ADB" disconnect "$SER" >/dev/null 2>&1; "$ADB" connect "$SER" >/dev/null 2>&1; echo "$TS offline重连" >> "$LOG"
  else
    "$ADB" connect "$SER" >/dev/null 2>&1; echo "$TS 未连(休眠)" >> "$LOG"
  fi
  sleep 30
done

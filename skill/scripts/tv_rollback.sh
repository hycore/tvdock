#!/bin/bash
# 一键解冻全部 blocked 包(回滚广告关闭/应用冻结)
# 用法: tv_rollback.sh <电视IP>
source "$(dirname "$0")/_common.sh"
[ -z "$1" ] && { echo "用法: $0 <电视IP>"; exit 2; }
tv_gate "$1"
SER="${1}:5555"

echo "== 解冻全部 blocked 包 =="
BLK=$("$ADB" -s "$SER" shell pm list packages -d 2>/dev/null | sed 's/package://')
[ -z "$BLK" ] && { echo "无需解冻"; exit 0; }
echo "$BLK" | while read -r p; do
  "$ADB" -s "$SER" shell pm unblock "$p" >/dev/null 2>&1
  sleep 0.5
  bl=$("$ADB" -s "$SER" shell dumpsys package "$p" 2>/dev/null | grep -c "blocked=true")
  [ "$bl" -eq 0 ] && echo "  ✔ $p" || echo "  ✘ $p"
done

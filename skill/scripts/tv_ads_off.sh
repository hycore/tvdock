#!/bin/bash
# 一键冻结广告/遥测/推送组件(13 个包,详见 docs/PACKAGES.md)
# 用法: tv_ads_off.sh <电视IP>
source "$(dirname "$0")/_common.sh"
[ -z "$1" ] && { echo "用法: $0 <电视IP>(电视的局域网 IP)"; exit 2; }
tv_gate "$1"
TV_IP="$1"; SER="${TV_IP}:5555"
LOG="$SKILL_DIR/backups/frozen_$(date '+%Y%m%d_%H%M%S').txt"
mkdir -p "$(dirname "$LOG")"

AD_PKGS=(
  com.miui.systemAdSolution com.miui.tv.analytics
  com.xiaomi.mitv.advertise com.xiaomi.devicereport
  com.xiaomi.mitv.kuyun.acr com.mitv.care
  com.xm.webcontent com.duokan.videodaily
  com.cmgame.gamehalltv com.xiaomi.gamecenter.sdk.service.mibox
  com.xiaomi.mibox.gamecenter com.xiaomi.tv.appupgrade
  com.xiaomi.mitv.upgrade
)
# 注:待机屏保(com.xiaomi.mibox.lockscreen)不在本脚本——它属于用户偏好,由向导单独询问
echo "== 广告/遥测冻结($SER)=="
ok=0; fail=0; frozen=""
for p in "${AD_PKGS[@]}"; do
  "$ADB" -s "$SER" shell pm block "$p" >/dev/null 2>&1; sleep 0.5
  bl=$("$ADB" -s "$SER" shell dumpsys package "$p" 2>/dev/null | grep -c "blocked=true")
  if [ "$bl" -gt 0 ]; then echo "  ✔ $p"; ok=$((ok+1)); frozen="$frozen $p"
  else echo "  ✘ $p"; fail=$((fail+1)); fi
done
echo "$frozen" | tr ' ' '\n' | grep -v '^$' > "$LOG"
echo "== 成功 $ok / 失败 $fail | 冻结清单: $LOG =="

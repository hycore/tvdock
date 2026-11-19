#!/bin/bash
# 一键冻结广告/遥测/推送组件(13 个基础包 + 4 个深查补删,详见 docs/PACKAGES.md)
# 版本感知冻结链见 _freeze.sh:Android 9+ 走 uninstall --user 0(持久,install-existing 可找回)
# 用法: tv_ads_off.sh <电视IP>
source "$(dirname "$0")/_common.sh"
source "$(dirname "$0")/_freeze.sh"
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
  # -- 深查补删(2026-11-19 Android 9 实机第二轮,遥测/推送/云控) --
  com.miui.analytics
  com.xiaomi.mitv.tvpush.tvpushservice
  com.xiaomi.mitv.healthdiagnosis
  com.mitv.cloudcontrol
)
# 注:待机屏保(com.xiaomi.mibox.lockscreen)不在本脚本——它属于用户偏好,由向导单独询问
echo "== 广告/遥测冻结($SER)=="
ok=0; fail=0; frozen=""
for p in "${AD_PKGS[@]}"; do
  if freeze_pkg "$p"; then echo "  ✔ $p"; ok=$((ok+1)); frozen="$frozen $p"
  else echo "  ✘ $p"; fail=$((fail+1)); fi
  sleep 0.5
done
echo "$frozen" | tr ' ' '\n' | grep -v '^$' > "$LOG"
echo "== 成功 $ok / 失败 $fail | 冻结清单: $LOG =="

#!/bin/bash
# 一键解冻全部 blocked 包(回滚广告关闭/应用冻结)
# 用法: tv_rollback.sh <电视IP>
source "$(dirname "$0")/_common.sh"
[ -z "$1" ] && { echo "用法: $0 <电视IP>"; exit 2; }
tv_gate "$1"
SER="${1}:5555"

echo "== 解冻/找回全部广告组件(blocked / suspended / uninstall --user 0 三种状态通吃)=="
AD_PKGS=(
  com.miui.systemAdSolution com.miui.tv.analytics
  com.xiaomi.mitv.advertise com.xiaomi.devicereport
  com.xiaomi.mitv.kuyun.acr com.mitv.care
  com.xm.webcontent com.duokan.videodaily
  com.cmgame.gamehalltv com.xiaomi.gamecenter.sdk.service.mibox
  com.xiaomi.mibox.gamecenter com.xiaomi.tv.appupgrade
  com.xiaomi.mitv.upgrade
)
for p in "${AD_PKGS[@]}"; do
  "$ADB" -s "$SER" shell pm unblock "$p" >/dev/null 2>&1
  "$ADB" -s "$SER" shell pm unsuspend "$p" >/dev/null 2>&1
  "$ADB" -s "$SER" shell pm enable "$p" >/dev/null 2>&1
  # 用户级卸载的找回(隐藏包不在 packages -d 列表,按路径判断)
  if [ -z "$("$ADB" -s "$SER" shell pm path "$p" 2>/dev/null)" ]; then
    "$ADB" -s "$SER" shell cmd package install-existing "$p" >/dev/null 2>&1
  fi
  st=$("$ADB" -s "$SER" shell pm path "$p" 2>/dev/null | grep -c "package:")
  [ "$st" -gt 0 ] && echo "  ✔ $p 已恢复" || echo "  ✘ $p 恢复失败"
  sleep 0.5
done
echo "== 恢复完成 =="

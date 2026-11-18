#!/bin/bash
# 静默安装器(uiautomator 守护自动点"继续安装",检测到删除/卸载字样跳过)
# 用法: tv_install.sh <电视IP> <apk路径>
# 跨平台:纯 bash + coreutils(Git Bash 可直接运行),无 python3/strings 依赖
source "$(dirname "$0")/_common.sh"
[ -z "$1" ] || [ -z "$2" ] && { echo "用法: $0 <电视IP> <apk路径>"; exit 2; }
TV_IP="$1"; APK="$2"; SER="${TV_IP}:5555"
TMPD="${TMPDIR:-/tmp}"
INST_LOG="$TMPD/tv_inst_$$.log"; WD_XML="$TMPD/tvi_wd_$$.xml"
trap 'rm -f "$INST_LOG" "$WD_XML"' EXIT
[ -f "$APK" ] || { echo "APK 不存在: $APK"; exit 2; }
tv_gate "$TV_IP"

# APK 元信息:优先 aapt2(自动探测常见 SDK 路径,可 AAPT=路径 覆盖),缺失则装完用设备端校验
AAPT="${AAPT:-}"
if [ -z "$AAPT" ]; then
  for c in "$HOME"/Library/Android/sdk/build-tools/*/aapt2 "$HOME"/Android/Sdk/build-tools/*/aapt2 /opt/android-sdk/build-tools/*/aapt2; do
    [ -x "$c" ] && AAPT="$c" && break
  done
fi
APK_VC=""; PKG=""
if [ -n "$AAPT" ] && [ -x "$AAPT" ]; then
  APK_VC=$("$AAPT" dump badging "$APK" 2>/dev/null | grep -oE "versionCode='[0-9]+'" | grep -oE "[0-9]+" | head -1)
  PKG=$("$AAPT" dump badging "$APK" 2>/dev/null | grep -oE "name='[^']+'" | head -1 | cut -d"'" -f2)
fi

# 从 uiautomator XML 提取确认按钮中心坐标(纯 bash,无 python3)
# 规则:出现"删除/卸载"字样整体放弃;否则取首个 文本=继续安装/安装/确定 且 clickable 的节点
extract_confirm_coord() {
  local xml="$1"
  grep -q "删除\|卸载" "$xml" && return 1
  local line
  line=$(grep -o '<node[^>]*>' "$xml" | grep 'clickable="true"' | grep -E 'text="(继续安装|安装|确 定|确定)"' | head -1)
  [ -z "$line" ] && return 1
  local nums
  # 注意:][ 是两组坐标的分隔符,必须先转成逗号再删括号,不能直接 tr -d '[]'
  nums=$(echo "$line" | grep -oE '\[[0-9]+,[0-9]+\]\[[0-9]+,[0-9]+\]' | head -1 | sed 's/\]\[/,/g; s/\[//g; s/\]//g')
  [ -z "$nums" ] && return 1
  local x1 y1 x2 y2
  x1=$(echo "$nums" | cut -d, -f1); y1=$(echo "$nums" | cut -d, -f2)
  x2=$(echo "$nums" | cut -d, -f3); y2=$(echo "$nums" | cut -d, -f4)
  [ -n "$x1" ] && [ -n "$x2" ] && echo "$(( (x1+x2)/2 )),$(( (y1+y2)/2 ))"
}

"$ADB" -s "$SER" install -r "$APK" > "$INST_LOG" 2>&1 &
PID=$!
i=0
while kill -0 "$PID" 2>/dev/null && [ "$i" -lt 90 ]; do
  sleep 2; i=$((i+1))
  "$ADB" -s "$SER" shell uiautomator dump /sdcard/wd.xml >/dev/null 2>&1
  "$ADB" -s "$SER" pull /sdcard/wd.xml "$WD_XML" >/dev/null 2>&1
  COORD=$(extract_confirm_coord "$WD_XML")
  if [ -n "$COORD" ]; then
    X=${COORD%,*}; Y=${COORD#*,}
    "$ADB" -s "$SER" shell input tap "$X" "$Y" >/dev/null 2>&1
    echo "[守护] 确认点击 ($COORD)"
    sleep 2
  fi
done
wait "$PID" 2>/dev/null
R=$(tail -1 "$INST_LOG" 2>/dev/null | tr -d '\r')
echo "安装输出: ${R:-无}"
if [ -n "$PKG" ] && [ -n "$APK_VC" ]; then
  CUR=$("$ADB" -s "$SER" shell dumpsys package "$PKG" 2>/dev/null | grep -oE "versionCode=[0-9]+" | head -1)
  [ "$CUR" = "versionCode=$APK_VC" ] && echo "✔ $PKG v$APK_VC 安装成功" || echo "✘ 校验失败(电视端: ${CUR:-无})"
else
  grep -q "Success" "$INST_LOG" && echo "✔ 安装成功(未做版本校验:本机无 aapt2,可设 AAPT=路径后重跑)" || echo "✘ 安装失败"
fi

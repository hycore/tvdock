#!/bin/bash
# 小橙子验收脚本(A1~A7 自动化)
# 用法: accept.sh <电视IP> <apk路径>
source "$(dirname "$0")/_common.sh"
[ -z "$1" ] || [ -z "$2" ] && { echo "用法: $0 <电视IP> <apk路径>"; exit 2; }
TV_IP="$1"; APK="$2"; SER="${TV_IP}:5555"
TMPD="${TMPDIR:-/tmp}"; ACC_DIR="$TMPD/xcz_acc"
[ -f "$APK" ] || { echo "APK 不存在: $APK"; exit 2; }
PKG="com.xiaochengzi.tvlive"
PASS=0; FAIL=0; SKIP=0
ok(){ echo "✔ $1"; PASS=$((PASS+1)); }
bad(){ echo "✘ $1"; FAIL=$((FAIL+1)); }
skip(){ echo "⚠ $1"; SKIP=$((SKIP+1)); }

# aapt2 可选:缺失时 A1/A2 跳过(设 AAPT=路径 可启用)
AAPT="${AAPT:-}"
if [ -z "$AAPT" ]; then
  for c in "$HOME"/Library/Android/sdk/build-tools/*/aapt2 "$HOME"/Android/Sdk/build-tools/*/aapt2 /opt/android-sdk/build-tools/*/aapt2; do
    [ -x "$c" ] && AAPT="$c" && break
  done
fi
HAVE_AAPT=0
[ -n "$AAPT" ] && [ -x "$AAPT" ] && HAVE_AAPT=1

tv_gate "$TV_IP"

if [ "$HAVE_AAPT" = "1" ]; then
  echo "== A1 APK 合规 =="
  BADGE=$("$AAPT" dump badging "$APK" 2>/dev/null)
  echo "$BADGE" | grep -q "package: name='$PKG'" && ok "A1.1 包名" || bad "A1.1 包名"
  MIN=$(echo "$BADGE" | grep -oE "minSdkVersion:'[0-9]+'" | grep -oE "[0-9]+")
  [ -n "$MIN" ] && [ "$MIN" -le 19 ] && ok "A1.2 minSdk=$MIN ≤19" || bad "A1.2 minSdk=$MIN"
  echo "$BADGE" | grep -q "armeabi-v7a" && ok "A1.3 含 v7a" || bad "A1.3 缺 v7a"
  TS=$(echo "$BADGE" | grep -oE "targetSdkVersion:'[0-9]+'" | grep -oE "[0-9]+")
  [ -n "$TS" ] && [ "$TS" -le 28 ] && ok "A1.4 targetSdk=$TS ≤28" || bad "A1.4 targetSdk=$TS"

  echo "== A2 无第三方 SDK =="
  mkdir -p "$ACC_DIR" && unzip -o -q "$APK" "classes*.dex" -d "$ACC_DIR" 2>/dev/null
  HIT=""
  # grep -aq 直接扫 dex 二进制,替代 strings(Git Bash 无 strings)
  for pat in com.umeng cn.jpush com.google.ads com.admob com.squareup.okhttp3 org.chromium; do
    grep -aq "$pat" "$ACC_DIR"/classes*.dex 2>/dev/null && HIT="$HIT $pat"
  done
  [ -z "$HIT" ] && ok "A2 无第三方 SDK" || bad "A2 发现:$HIT"
else
  skip "A1/A2 跳过(本机无 aapt2;安装 Android build-tools 或设环境变量 AAPT=路径后重跑)"
fi

echo "== A3 安装 =="
"$ADB" -s "$SER" install -r "$APK" 2>&1 | tail -1 | grep -q "Success" && ok "A3 安装 Success" || bad "A3 安装失败"

echo "== A4/A5 启动 =="
if [ "$HAVE_AAPT" = "1" ]; then
  MAIN=$("$AAPT" dump badging "$APK" 2>/dev/null | grep launchable-activity | grep -oE "name='[^']+'" | head -1 | cut -d"'" -f2)
  "$ADB" -s "$SER" shell am force-stop "$PKG" >/dev/null 2>&1; sleep 1
  "$ADB" -s "$SER" shell am start -n "$PKG/$MAIN" >/dev/null 2>&1
else
  # 无 aapt2 时用 monkey 拉起默认 LAUNCHER activity
  "$ADB" -s "$SER" shell am force-stop "$PKG" >/dev/null 2>&1; sleep 1
  "$ADB" -s "$SER" shell monkey -p "$PKG" -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1
fi
T0=$(date +%s); fg=""
for i in $(seq 1 15); do sleep 1; "$ADB" -s "$SER" shell dumpsys activity activities 2>/dev/null | grep -q "mResumedActivity.*$PKG" && { fg=1; break; }; done
T1=$(date +%s)
[ -n "$fg" ] && ok "A4 启动 $((T1-T0))s" || bad "A4 15s 未到前台"
sleep 20
"$ADB" -s "$SER" shell "screencap -p /sdcard/a5.png" >/dev/null 2>&1
"$ADB" -s "$SER" pull /sdcard/a5.png "$ACC_DIR/a5.png" >/dev/null 2>&1
SZ=$(wc -c < "$ACC_DIR/a5.png" 2>/dev/null || echo 0)
[ "$SZ" -gt 100000 ] && ok "A5 画面 ${SZ}B >100KB" || bad "A5 截图 ${SZ}B"
FATAL=$("$ADB" -s "$SER" shell "logcat -d" 2>/dev/null | grep -cE "FATAL.*$PKG")
[ "${FATAL:-0}" = "0" ] && ok "A5b 无 FATAL" || bad "A5b FATAL=$FATAL"

echo "== A6 内存 =="
PSS=$("$ADB" -s "$SER" shell dumpsys meminfo "$PKG" 2>/dev/null | grep -oE "TOTAL PSS[^0-9]*[0-9]+" | grep -oE "[0-9]+$" | head -1)
[ -n "$PSS" ] && [ "$PSS" -le 153600 ] && ok "A6 PSS=${PSS}KB ≤150MB" || bad "A6 PSS=${PSS}KB 超标"

echo "== A7 进程干净 =="
EXTRA=$("$ADB" -s "$SER" shell ps 2>/dev/null | grep "^u0_a" | grep -vE "$PKG|systemui|acore|media|sogou|soundbar|kuyun|mitv.services|pico|tweather" | grep -v "NAME" | wc -l)
[ "${EXTRA:-0}" = "0" ] && ok "A7 无新增进程" || bad "A7 $EXTRA 个可疑进程"

echo "======== 验收结果: 通过 $PASS / 失败 $FAIL / 跳过 $SKIP ========"
exit "$FAIL"

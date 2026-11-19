#!/bin/bash
# 通用冻结/恢复库(版本感知)—— source 本文件后使用
# 依赖:调用方需已就绪 $ADB(adb 命令)与 $SER(电视序列号 IP:5555)
#
# ADB 命令兼容矩阵(实机/系统版本差异,详见 SKILL.md「ADB 命令兼容矩阵」):
#   Android 9 (SDK 28,如 MiTV-ASTP0): pm block 不存在;suspend 重启后不持久
#              → 首选 pm uninstall --user 0(跨重启持久,cmd package install-existing 可找回)
#   Android 4.4 MIUI TV(如 3S hancock): pm block 可用(已验证)
#   API 24+(Android 7+): pm suspend 可用(非小米系统或未重置场景可用)
# 每种方式执行后都做状态验证,失败自动降级下一方式;全部失败返回非 0

tv_sdk() {
  TV_SDK=$("$ADB" -s "$SER" shell getprop ro.build.version.sdk 2>/dev/null | tr -d '\r\n ')
  [ -z "$TV_SDK" ] && TV_SDK=0
}

# 验证包是否已"不可用"(卸载/挂起/停用任一状态成立即算已冻结)
frozen_check() {
  local p="$1"
  [ -z "$("$ADB" -s "$SER" shell pm path "$p" 2>/dev/null)" ] && return 0
  "$ADB" -s "$SER" shell dumpsys package "$p" 2>/dev/null | grep -q "suspended=true" && return 0
  "$ADB" -s "$SER" shell dumpsys package "$p" 2>/dev/null | grep -q "blocked=true" && return 0
  "$ADB" -s "$SER" shell pm list packages -d 2>/dev/null | grep -q "package:$p" && return 0
  return 1
}

# 冻结一个包(自动按系统版本选命令;返回 0=成功)
freeze_pkg_impl() {
  local p="$1"
  tv_sdk
  if [ "$TV_SDK" -ge 28 ]; then
    # Android 9+ 实测:pm block 不存在;suspend 重启不持久 → 卸载优先
    "$ADB" -s "$SER" shell pm uninstall --user 0 "$p" >/dev/null 2>&1; sleep 0.5
    frozen_check "$p" && return 0
    "$ADB" -s "$SER" shell pm disable-user --user 0 "$p" >/dev/null 2>&1; sleep 0.5
    frozen_check "$p" && return 0
    return 1
  fi
  if [ "$TV_SDK" -ge 24 ]; then
    "$ADB" -s "$SER" shell pm suspend "$p" >/dev/null 2>&1; sleep 0.5
    frozen_check "$p" && return 0
  fi
  "$ADB" -s "$SER" shell pm disable-user --user 0 "$p" >/dev/null 2>&1; sleep 0.5
  frozen_check "$p" && return 0
  "$ADB" -s "$SER" shell pm block "$p" >/dev/null 2>&1; sleep 0.5
  frozen_check "$p" && return 0
  return 1
}

# 恢复一个包(unblock/unsuspend/enable/install-existing 全状态覆盖;返回 0=可见)
restore_pkg_impl() {
  local p="$1"
  "$ADB" -s "$SER" shell pm unblock "$p" >/dev/null 2>&1
  "$ADB" -s "$SER" shell pm unsuspend "$p" >/dev/null 2>&1
  "$ADB" -s "$SER" shell pm enable "$p" >/dev/null 2>&1
  if [ -z "$("$ADB" -s "$SER" shell pm path "$p" 2>/dev/null)" ]; then
    "$ADB" -s "$SER" shell cmd package install-existing "$p" >/dev/null 2>&1
  fi
  [ -n "$("$ADB" -s "$SER" shell pm path "$p" 2>/dev/null)" ]
}

# 各脚本本地包装:统一入口(依赖调用方的 $ADB/$SER)
freeze_pkg(){ freeze_pkg_impl "$1"; }
restore_pkg(){ restore_pkg_impl "$1"; }

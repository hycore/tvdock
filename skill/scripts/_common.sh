#!/bin/bash
# 公共库:adb 定位 + 连接门禁(scripts/ 内各脚本 source 本文件)
# 平台:macOS / Linux / Windows Git Bash(含 MSYS);Windows 用户请用 Git Bash 运行
# 不要直接运行本文件

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[1]}")" && pwd)"
SKILL_DIR="$(dirname "$SCRIPT_DIR")"

# ── adb 定位:PATH 优先,其次 skill 自带的 bin/platform-tools(env_check.sh --install 装的)──
if command -v adb >/dev/null 2>&1; then
  ADB="adb"
elif [ -x "$SKILL_DIR/bin/platform-tools/adb" ]; then
  ADB="$SKILL_DIR/bin/platform-tools/adb"
elif [ -x "$SKILL_DIR/bin/platform-tools/adb.exe" ]; then
  ADB="$SKILL_DIR/bin/platform-tools/adb.exe"
else
  echo "未找到 adb。请先运行: bash scripts/env_check.sh --install(支持 macOS / Linux / Windows 自动安装)"
  exit 4
fi

# ── 连接门禁:tv_gate <电视IP>,不可达退出码 3 ──
tv_gate() {
  local ip="$1" ser="${1}:5555"
  "$ADB" connect "$ser" >/dev/null 2>&1
  sleep 2
  if [ "$("$ADB" devices 2>/dev/null | grep "$ip" | awk '{print $2}')" != "device" ]; then
    echo "电视不可达($ip): 请确认电视已开机、与本机同一局域网、且已开启 ADB 调试(设置→账号与安全→ADB调试)"
    exit 3
  fi
}

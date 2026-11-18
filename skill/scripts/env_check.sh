#!/bin/bash
# 环境自检 + adb 一键安装(零依赖用户直接跑这个)
# 用法:
#   bash scripts/env_check.sh            # 仅自检:adb / unzip / curl 缺什么告诉你怎么装
#   bash scripts/env_check.sh --install  # 缺 adb 时自动安装(Google 官方 platform-tools)
# 平台支持:macOS / Linux / Windows Git Bash(含 MSYS)/ WSL
# 下载源:dl.google.com → 腾讯云镜像自动回退(国内网络直连 Google 常不可达)
SKILL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BIN_DIR="$SKILL_DIR/bin"
TMPD="${TMPDIR:-/tmp}"
DO_INSTALL=0
[ "$1" = "--install" ] && DO_INSTALL=1

have() { command -v "$1" >/dev/null 2>&1; }

platform() {
  case "$(uname -s)" in
    Darwin)               echo "macOS" ;;
    Linux)                echo "Linux" ;;
    MINGW*|MSYS*|CYGWIN*) echo "Windows(Git Bash)" ;;
    *)                    echo "未知($(uname -s))" ;;
  esac
}

platform_key() {
  case "$(uname -s)" in
    Darwin)               echo "darwin" ;;
    Linux)                echo "linux" ;;
    MINGW*|MSYS*|CYGWIN*) echo "windows" ;;
    *)                    echo "" ;;
  esac
}

echo "== 环境自检(平台: $(platform))=="

# 1) adb
ADB_OK=0
ADB_BIN=""
if have adb; then
  ADB_OK=1; ADB_BIN="$(command -v adb)"
  echo "✔ adb: $($ADB_BIN version 2>/dev/null | head -1)"
elif [ -x "$BIN_DIR/platform-tools/adb" ]; then
  ADB_OK=1; ADB_BIN="$BIN_DIR/platform-tools/adb"
  echo "✔ adb: $($ADB_BIN version 2>/dev/null | head -1)(skill 自带)"
elif [ -x "$BIN_DIR/platform-tools/adb.exe" ]; then
  ADB_OK=1; ADB_BIN="$BIN_DIR/platform-tools/adb.exe"
  echo "✔ adb: $($ADB_BIN version 2>/dev/null | head -1)(skill 自带)"
else
  echo "✘ adb: 未安装"
fi

# 2) 辅助工具
have unzip && echo "✔ unzip" || echo "⚠ unzip 缺失(有 python3 也可解压)"
have curl   && echo "✔ curl"   || { have wget && echo "✔ wget(替代 curl)" || echo "⚠ curl/wget 均缺失,无法自动下载"; }

fetch() { # fetch <url> <输出文件>
  if have curl; then curl -fsSL --retry 2 --connect-timeout 15 --max-time 600 -o "$2" "$1"
  elif have wget; then wget -q -T 15 -O "$2" "$1"
  else return 9; fi
}

install_from_remote() {
  local key; key=$(platform_key)
  [ -z "$key" ] && { echo "✘ 无法识别平台,请手动下载: https://developer.android.com/tools/releases/platform-tools"; return 1; }
  local tmp="${TMPD:-/tmp}/platform-tools-${key}.zip"
  DL_OK=0
  # 源顺序:Google 官方 → 腾讯云镜像
  local urls=(
    "https://dl.google.com/android/repository/platform-tools-latest-${key}.zip"
    "https://mirrors.cloud.tencent.com/AndroidSDK/platform-tools-latest-${key}.zip"
  )
  for u in "${urls[@]}"; do
    echo "→ 下载 $u"
    if fetch "$u" "$tmp" && [ -s "$tmp" ]; then DL_OK=1; break; fi
    echo "  该源不可达,尝试下一个源"
  done
  if [ "$DL_OK" != "1" ]; then rm -f "$tmp"; echo "✘ 全部下载源失败,请手动下载 zip 解压到: $BIN_DIR/"; return 1; fi
  echo "→ 解压到 $BIN_DIR/"
  if have unzip; then unzip -o -q "$tmp" -d "$BIN_DIR/"
  elif have python3; then python3 -m zipfile -e "$tmp" "$BIN_DIR/"
  else rm -f "$tmp"; echo "✘ 无 unzip/python3,请手动解压 $tmp 到 $BIN_DIR/"; return 1; fi
  rm -f "$tmp"
  [ -x "$BIN_DIR/platform-tools/adb" ] || [ -x "$BIN_DIR/platform-tools/adb.exe" ]
}

install_via_pkg() {
  case $(platform_key) in
    mac)
      if have brew; then echo "→ brew install android-platform-tools"; brew install -q android-platform-tools; else return 1; fi ;;
    linux)
      if have apt-get; then sudo apt-get update -qq && sudo apt-get install -y adb
      elif have dnf; then sudo dnf install -y android-tools
      elif have pacman; then sudo pacman -S --noconfirm android-tools
      else return 1; fi ;;
    *) return 1 ;;
  esac
}

if [ "$ADB_OK" = "0" ]; then
  if [ "$DO_INSTALL" = "1" ]; then
    echo "→ 尝试自动安装 adb..."
    if install_via_pkg || install_from_remote; then
      if have adb; then ADB_OK=1; echo "✔ adb 安装成功: $(adb version | head -1)"
      elif [ -x "$BIN_DIR/platform-tools/adb" ] || [ -x "$BIN_DIR/platform-tools/adb.exe" ]; then
        ADB_OK=1; ADB_BIN="$BIN_DIR/platform-tools/adb"; [ -x "$BIN_DIR/platform-tools/adb.exe" ] && ADB_BIN="$BIN_DIR/platform-tools/adb.exe"
        echo "✔ adb 安装成功: $($ADB_BIN version | head -1)"
        echo "  (skill 脚本会自动使用它,无需配 PATH;想全局可用可执行: export PATH=\"$BIN_DIR/platform-tools:\$PATH\")"
      fi
    fi
    [ "$ADB_OK" = "0" ] && echo "✘ 自动安装失败,请按下方手动指引操作"
  else
    echo ""
    echo "adb 未安装。三种方式任选:"
    echo "  ① 一键自动安装:   bash scripts/env_check.sh --install(自动回退国内镜像)"
    echo "  ② macOS Homebrew: brew install android-platform-tools"
    echo "  ③ 手动下载 zip(解压到 $BIN_DIR/ 即可,脚本自动识别):"
    echo "     Google:  https://dl.google.com/android/repository/platform-tools-latest-<windows|linux|darwin>.zip"
    echo "     国内镜像: https://mirrors.cloud.tencent.com/AndroidSDK/platform-tools-latest-<windows|linux|darwin>.zip"
  fi
fi

# 结果 + 电视侧前提
if [ "$ADB_OK" = "1" ]; then
  echo ""
  echo "== 环境就绪。电视侧还需满足: =="
  echo "  1. 电视已开机且与本机同一局域网"
  echo "  2. 电视已开启 ADB 调试(设置→账号与安全→ADB调试=允许)"
  echo "  3. 试连: bash scripts/tv_status.sh <电视IP>"
else
  exit 4
fi

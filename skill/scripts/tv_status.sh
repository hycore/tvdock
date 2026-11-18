#!/bin/bash
# 应用状态总览(冻结包/第三方包/总包数)
# 用法: tv_status.sh <电视IP>
source "$(dirname "$0")/_common.sh"
[ -z "$1" ] && { echo "用法: $0 <电视IP>"; exit 2; }
tv_gate "$1"
SER="${1}:5555"

echo "== 已冻结 =="; "$ADB" -s "$SER" shell pm list packages -d 2>/dev/null | sed 's/package://' | sort
echo "== 第三方应用 =="; "$ADB" -s "$SER" shell pm list packages -3 2>/dev/null | sed 's/package://' | sort
echo "== 总包数 =="; "$ADB" -s "$SER" shell pm list packages 2>/dev/null | wc -l

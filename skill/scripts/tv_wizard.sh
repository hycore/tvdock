#!/bin/bash
# 电视优化向导(傻瓜模式):不懂 adb / 安卓也能用,全程一问一答
# 用法: bash scripts/tv_wizard.sh
# 流程: 连电视 → 选套餐 → 问屏保 → 确认应用 → 执行 → 出人话报告
# 原则: 只"收起"不"删除",随时可恢复;您自己装的应用一律不动
SKILL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TMPD="${TMPDIR:-/tmp}"
DESC="$SKILL_DIR/scripts/pkg_desc.txt"
ANS=""

say(){ echo ""; echo "======== $1 ========"; }
ask(){ printf "%s" "$1"; read -r ANS; }
have(){ command -v "$1" >/dev/null 2>&1; }

# ── 第 0 步:工具准备(用户不需要知道 adb 是什么) ──
ADB=""
if have adb; then ADB="adb"
elif [ -x "$SKILL_DIR/bin/platform-tools/adb" ]; then ADB="$SKILL_DIR/bin/platform-tools/adb"
elif [ -x "$SKILL_DIR/bin/platform-tools/adb.exe" ]; then ADB="$SKILL_DIR/bin/platform-tools/adb.exe"
else
  say "第一次使用"
  echo "需要安装一个小工具(约 40MB,只装在向导自己的文件夹里,不影响电脑)。"
  ask "现在自动安装吗?[回车=安装 / 输入 n=退出] "
  [ "$ANS" = "n" ] && { echo "已退出。"; exit 0; }
  bash "$SKILL_DIR/scripts/env_check.sh" --install || { echo "安装失败,请检查网络后重试。"; exit 4; }
  ADB="adb"
  have adb || ADB="$SKILL_DIR/bin/platform-tools/adb"
  [ -x "$ADB.exe" ] 2>/dev/null && ADB="$ADB.exe"
fi

# ── 第 1 步:打开开发者模式(小米电视默认隐藏开发者入口,不开就看不到 ADB 调试)──
say "第一步:打开\"开发者模式\""
echo "小米电视默认把开发者相关的设置藏起来了,需要先把它显示出来。"
echo ""
echo "请拿遥控器按下面步骤操作:"
echo "  ① 按遥控器上的【设置】键,进入【关于】(或【关于本机】)"
echo "  ② 把光标停在【产品型号】(或【系统版本】)这一行上"
echo "  ③ 连按遥控器中间的【确认键(OK键)】4 次"
echo "  ④ 看到\"已进入开发者模式\"的提示就成功了"
echo "     (个别机型是连按【菜单键】4 次;如果电视本来就能看到相关设置,本步可跳过)"
echo ""
ask "操作好了吗?[回车=已打开,继续 / 输入 n=没反应,先退出] "
if [ "$ANS" = "n" ]; then
  echo ""
  echo "没关系,个别型号的进入方式略有不同。请告诉我您的电视型号,查到准确方法后再运行本向导。"
  exit 0
fi

# ── 第 2 步:打开 ADB调试(开发者开关)──
say "第二步:打开\"ADB调试\""
echo "开启开发者模式后,电视里才看得到这个开关。"
echo ""
echo "请拿遥控器继续操作:"
echo "  ① 回到【设置】→【账号与安全】"
echo "     (开启开发者模式后,有的电视会多出一个【开发者选项】菜单,去那里找)"
echo "  ② 找到【ADB调试】,把它选成【允许】"
echo "  ③ 如果弹出警告提示框,选【允许/确定】"
echo ""
ask "操作好了吗?[回车=已打开,继续 / 输入 n=我还没找到,先退出] "
if [ "$ANS" = "n" ]; then
  echo ""
  echo "没关系。找到【账号与安全】→【ADB调试】打开后,重新运行本向导即可。"
  echo "如果电视里翻遍了都没有这个选项,把电视型号告诉我,我帮你查准确位置。"
  exit 0
fi

# ── 第 3 步:找到电视 IP 并连接 ──
say "第三步:找到电视的 IP 地址并连接"
echo "IP 地址就是电视在网络里的\"门牌号\",4 段数字用点隔开(如 192.168.1.25)。"
echo "在电视上这样看:"
echo "  【设置】→【关于】→【本机信息】(或【网络信息】),找\"IP地址\"那一行"
echo "实在找不到也可以:登录路由器管理页(浏览器输入 192.168.1.1 或 192.168.0.1 试试),"
echo "在\"已连接设备\"里找到您的电视名字,旁边就是 IP。"
echo ""
TRY=0; RETRY=0
connected(){ [ "$("$ADB" devices 2>/dev/null | grep "$TV_IP" | awk '{print $2}')" = "device" ]; }
while :; do
  TRY=$((TRY+1))
  [ "$TRY" -gt 5 ] && { echo "尝试次数有点多了,先退出。想清楚 IP 后重新运行向导。"; exit 2; }
  if [ "$RETRY" = "0" ]; then
    ask "请输入电视的 IP 地址(输 q 退出): "
    TV_IP="$ANS"
    [ "$TV_IP" = "q" ] && { echo "已退出。"; exit 0; }
    if ! echo "$TV_IP" | grep -qE '^[0-9]{1,3}(\.[0-9]{1,3}){3}$'; then
      echo "  这串数字不像 IP——要 4 段数字、用点隔开,比如 192.168.1.25。请再看一眼电视,重新输入。"
      continue
    fi
    SER="${TV_IP}:5555"
  fi
  echo "  正在连接电视…"
  "$ADB" connect "$SER" >/dev/null 2>&1; sleep 2
  connected && break
  echo "  没连上。按顺序检查这三条:"
  echo "    ① 【ADB调试】真的打开了吗?→【设置】→【账号与安全】→【ADB调试】→【允许】"
  echo "    ② 电视和电脑在同一个网络吗?→ 电视连的 WiFi 和电脑连的要是同一个路由器"
  echo "    ③ IP 有没有看错?→ 到【设置】→【关于】→【本机信息】再核对一遍"
  echo "  (也有可能电视在待机——用遥控器按任意键把它叫醒)"
  echo ""
  ask "  回车=再试一次 / 输 1=重新输入 IP / 输 n=退出: "
  case "$ANS" in
    n) echo "已退出。处理好后重新运行向导即可,不会对电视有任何影响。"; exit 3 ;;
    1) RETRY=0 ;;
    *) RETRY=1 ;;
  esac
done
MODEL=$("$ADB" -s "$SER" shell getprop ro.product.model 2>/dev/null | tr -d '\r')
echo "  ✔ 连上了:${MODEL:-电视}(IP $TV_IP)"

# ── 包名/人话 工具函数 ──
# desc_of <包名> <列号:2=短名 3=是什么 4=关掉影响>
desc_of(){ grep "^$1|" "$DESC" 2>/dev/null | head -1 | cut -d'|' -f"$2"; }
installed(){ "$ADB" -s "$SER" shell pm list packages 2>/dev/null | tr -d '\r' | sed 's/package://' | grep -qx "$1"; }

source "$(dirname "$0")/_freeze.sh"   # 版本感知实现(block/suspend/uninstall 自动降级)
# 收起/恢复:统一走 _freeze.sh 的版本感知实现
freeze_pkg(){ freeze_pkg_impl "$1"; }
unfreeze_pkg(){ restore_pkg_impl "$1"; }

# ── 第 4 步:选套餐 ──
say "第四步:选择优化套餐"
cat << 'MENU'
请输入数字后回车:
  1) 温和优化 —— 只关闭广告和"窥探"类的功能,电视上原有节目应用全部保留(想省心选这个)
  2) 极简安心 —— 在套餐1的基础上,把预装的购物/游戏/推广类应用也收起,电视更清爽
  3) 全部恢复 —— 把之前优化时关掉的东西全部找回来,电视回到原状
MENU
ask "套餐编号 [1/2/3,回车=1]: "
MODE="$ANS"
case "$MODE" in 1|2|3) ;; *) MODE=1 ;; esac

# ── 恢复模式直接执行 ──
if [ "$MODE" = "3" ]; then
  say "恢复模式"
  echo "正在找回所有被收起的功能和应用…"
  N=0; F=0
  "$ADB" -s "$SER" shell pm list packages -d 2>/dev/null | tr -d '\r' | sed 's/package://' | while read -r p; do
    [ -z "$p" ] && continue
    NAME=$(desc_of "$p" 2); [ -z "$NAME" ] && NAME="$p"
    if unfreeze_pkg "$p"; then echo "  ✔ 已恢复:$NAME"; else echo "  ✘ 恢复失败:$NAME"; fi
    sleep 0.5
  done
  echo ""
  echo "恢复完成。提醒:如果\"系统自动升级\"被恢复,电视以后可能自动升级,升级会重置之前做的优化。"
  exit 0
fi

# ── 第 5 步:待机屏保 ──
say "第五步:待机屏保"
echo "待机屏保 = 电视闲着不动时轮播的图片(画面多为官方推广图)。"
KEEP_SS=1
ask "保留待机屏保吗?[回车=保留 / 输入 n=关闭] "
[ "$ANS" = "n" ] && KEEP_SS=0

# ── 第 6 步:逐个确认预装应用 ──
say "第六步:确认电视上的应用"
echo "您自己安装的应用(直播、桌面等)一律原样保留,不会动。"
echo "以下是电视预装的内容类应用(只在已安装的里面挑):"

# 列出已安装的内容类应用(编号 → 包名 存入映射文件)
MAP="$TMPD/tv_wizard_map_$$.txt"; trap 'rm -f "$MAP"' EXIT
IDX=0; DEFAULT_ALL=0   # 套餐2默认收起全部;套餐1默认全部保留
for LINE in $(grep -v '^#' "$DESC" | cut -d'|' -f1); do
  PKG_S=$(echo "$LINE" | head -1)
  [ -z "$PKG_S" ] && continue
  # 跳过套餐1固定关的广告类(它们不属于"内容应用",单独列出)
  case "$PKG_S" in
    com.xiaomi.mitv.advertise|com.miui.systemAdSolution|com.miui.tv.analytics|com.xiaomi.devicereport|com.xiaomi.mitv.kuyun.acr|com.mitv.care|com.xm.webcontent|com.duokan.videodaily|com.cmgame.gamehalltv|com.xiaomi.gamecenter.sdk.service.mibox|com.xiaomi.mibox.gamecenter|com.xiaomi.tv.appupgrade|com.xiaomi.mitv.upgrade|com.xiaomi.mibox.lockscreen) continue ;;
  esac
  installed "$PKG_S" || continue
  IDX=$((IDX+1))
  echo "$IDX $PKG_S" >> "$MAP"
  echo "  $IDX) $(desc_of "$PKG_S" 2) —— $(desc_of "$PKG_S" 3)"
done

REMOVES=""
KEEPS=""
if [ "$IDX" -gt 0 ]; then
  if [ "$MODE" = "2" ]; then
    DEFAULT_ALL=1
    echo ""
    ask "套餐2默认把上面这些全部收起。想保留哪个就输编号(逗号分隔,回车=全部收起): "
    KEEPS="$ANS"
  else
    echo ""
    ask "想去掉哪个就输编号(逗号分隔,回车=全部保留): "
    REMOVES="$ANS"
  fi
else
  echo "  (这台电视上没有可挑选的预装内容应用)"
fi

# ── 第 7 步:确认执行 ──
say "第七步:开始优化"
echo "即将执行:"
echo "  · 关闭开机广告、首页推广、弹窗提醒、观看记录上传 等 13 项"
[ "$KEEP_SS" = "0" ] && echo "  · 关闭待机屏保(按您的要求)" || echo "  · 保留待机屏保"
if [ "$IDX" -gt 0 ] && [ "$DEFAULT_ALL" = "1" ]; then
  echo "  · 收起预装内容应用(除您指定保留的)"
elif [ -n "$REMOVES" ]; then
  echo "  · 收起您选中的预装应用"
fi
echo "  · 您自己装的应用一律不动"
echo "(所有\"收起\"都只是暂停显示,随时可在恢复模式找回来)"
ask "确认执行?[回车=开始 / 输入 n=取消] "
if [ "$ANS" = "n" ]; then echo "已取消,什么都没改。"; exit 0; fi

# ── 执行:固定 13 项广告/跟踪 ──
REPORT="$SKILL_DIR/backups/优化报告_$(date '+%Y%m%d_%H%M').txt"
mkdir -p "$(dirname "$REPORT")"
{
echo "============ 电视优化报告 $(date '+%Y-%m-%d %H:%M') ============"
echo "电视:${MODEL:-未知}(IP $TV_IP)  套餐:$([ "$MODE" = "1" ] && echo 温和优化 || echo 极简安心)"
echo ""
echo "【本次优化做了什么】"
} > "$REPORT"

OKN=0; FAILN=0
for LINE in $(grep -v '^#' "$DESC" | cut -d'|' -f1); do
  PKG_F=$(echo "$LINE" | head -1)
  [ -z "$PKG_F" ] && continue
  case "$PKG_F" in
    com.xiaomi.mitv.advertise|com.miui.systemAdSolution|com.miui.tv.analytics|com.xiaomi.devicereport|com.xiaomi.mitv.kuyun.acr|com.mitv.care|com.xm.webcontent|com.duokan.videodaily|com.cmgame.gamehalltv|com.xiaomi.gamecenter.sdk.service.mibox|com.xiaomi.mibox.gamecenter|com.xiaomi.tv.appupgrade|com.xiaomi.mitv.upgrade) ;;
    *) continue ;;
  esac
  installed "$PKG_F" || continue
  NAME=$(desc_of "$PKG_F" 2)
  printf "  正在关闭:%s…" "$NAME"
  if freeze_pkg "$PKG_F"; then echo " ✔"; echo "  ✔ 已关闭:$NAME —— $(desc_of "$PKG_F" 4)" >> "$REPORT"; OKN=$((OKN+1))
  else echo " ✘(跳过,不影响其他项)"; echo "  ✘ 未成功:$NAME" >> "$REPORT"; FAILN=$((FAILN+1)); fi
done

# 屏保
SS_NAME=$(desc_of com.xiaomi.mibox.lockscreen 2)
if installed com.xiaomi.mibox.lockscreen; then
  if [ "$KEEP_SS" = "0" ]; then
    printf "  正在关闭:%s…" "$SS_NAME"
    if freeze_pkg com.xiaomi.mibox.lockscreen; then echo " ✔"; echo "  ✔ 已关闭:$SS_NAME(按您的要求)" >> "$REPORT"; OKN=$((OKN+1))
    else echo " ✘"; echo "  ✘ 未成功:$SS_NAME" >> "$REPORT"; FAILN=$((FAILN+1)); fi
  else
    echo "  保留:$SS_NAME(按您的要求)"
    echo "  · 保留:$SS_NAME" >> "$REPORT"
  fi
fi

# 内容应用
echo "" >> "$REPORT"; echo "【收起的应用(随时可恢复)】" >> "$REPORT"; HAS_RM=0
while IFS=' ' read -r N P; do
  [ -z "$N" ] && continue
  NAME=$(desc_of "$P" 2); [ -z "$NAME" ] && NAME="$P"
  if [ "$DEFAULT_ALL" = "1" ]; then
    case ",$KEEPS," in *",$N,"*) echo "  保留:$NAME(按您的要求)"; echo "  · 保留:$NAME" >> "$REPORT"; continue ;; esac
    printf "  正在收起:%s…" "$NAME"
    if freeze_pkg "$P"; then echo " ✔"; echo "  ✔ 已收起:$NAME —— $(desc_of "$P" 4)" >> "$REPORT"; HAS_RM=1; OKN=$((OKN+1))
    else echo " ✘"; echo "  ✘ 未成功:$NAME" >> "$REPORT"; FAILN=$((FAILN+1)); fi
  else
    case ",$REMOVES," in *",$N,"*)
      printf "  正在收起:%s…" "$NAME"
      if freeze_pkg "$P"; then echo " ✔"; echo "  ✔ 已收起:$NAME —— $(desc_of "$P" 4)" >> "$REPORT"; HAS_RM=1; OKN=$((OKN+1))
      else echo " ✘"; echo "  ✘ 未成功:$NAME" >> "$REPORT"; FAILN=$((FAILN+1)); fi ;;
    esac
  fi
done < "$MAP"

# ── 人话总结报告 ──
USER_APPN=$("$ADB" -s "$SER" shell pm list packages -3 2>/dev/null | tr -d '\r' | grep -c .)
{
[ "$HAS_RM" = "0" ] && echo "  (无,按您的选择全部保留)"
echo ""
echo "【保留的内容】"
echo "  · 您自己安装的应用共 ${USER_APPN} 个,全部原样保留"
echo ""
echo "【如何找回】"
echo "  随时可以恢复:重新运行本向导选\"3 全部恢复\",或对助手说\"把电视恢复原状\"。"
echo ""
echo "【技术备注(可忽略)】"
echo "  成功 $OKN 项,未成功 $FAILN 项;以上\"收起\"通过系统冻结实现,未删除任何文件。"
echo "============================================"
} >> "$REPORT"

say "完成!"
cat "$REPORT"
echo ""
echo "报告已保存到: $REPORT"

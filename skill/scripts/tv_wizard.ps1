# 电视优化向导(Windows 版):不懂 adb / 安卓也能用
# 运行方式:双击同目录 tv_wizard.bat(无需安装任何东西,PowerShell 是 Windows 自带的)
# 流程: 连电视 → 选套餐 → 问屏保 → 确认应用 → 执行 → 出人话报告
# 原则: 只"收起"不"删除",随时可恢复;您自己装的应用一律不动
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"
try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 } catch {}

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$SkillDir  = Split-Path -Parent $ScriptDir
$BinDir    = Join-Path $SkillDir "bin"
$DescFile  = Join-Path $ScriptDir "pkg_desc.txt"
$BackupDir = Join-Path $SkillDir "backups"
$script:ADB = $null
$script:TVIP = ""
$script:SER  = ""

function Say($t) { Write-Host ""; Write-Host "======== $t ========" }

# ── 工具准备(用户不需要知道 adb 是什么) ──
function Resolve-Adb {
  $cmd = Get-Command adb -ErrorAction SilentlyContinue
  if ($cmd) { return "adb" }
  $local = Join-Path $BinDir "platform-tools\adb.exe"
  if (Test-Path $local) { return $local }
  return $null
}

$script:ADB = Resolve-Adb
if (-not $script:ADB) {
  Say "第一次使用"
  Write-Host "需要安装一个小工具(约 40MB,只装在向导自己的文件夹里,不影响电脑)。"
  $a = Read-Host "现在自动安装吗?[回车=安装 / 输入 n=退出]"
  if ($a -eq "n") { Write-Host "已退出。"; exit 0 }
  New-Item -ItemType Directory -Force -Path $BinDir | Out-Null
  $zip = Join-Path $env:TEMP "platform-tools-windows.zip"
  $urls = @(
    "https://dl.google.com/android/repository/platform-tools-latest-windows.zip",
    "https://mirrors.cloud.tencent.com/AndroidSDK/platform-tools-latest-windows.zip"
  )
  $dl = $false
  foreach ($u in $urls) {
    Write-Host "正在下载(约 40MB)…"
    try { Invoke-WebRequest -Uri $u -OutFile $zip -UseBasicParsing; $dl = $true; break }
    catch { Write-Host "  这个下载源连不上,自动换一个源…" }
  }
  if (-not $dl) { Write-Host "下载失败,请检查网络后重跑。"; exit 4 }
  Write-Host "正在解压…"
  Expand-Archive -Path $zip -DestinationPath $BinDir -Force
  Remove-Item $zip -Force
  $script:ADB = Resolve-Adb
  if (-not $script:ADB) { Write-Host "安装异常:没有找到小工具,请重跑。"; exit 4 }
  Write-Host "小工具装好了。"
}

# ── 第一步:打开开发者模式(小米电视默认隐藏开发者入口,不开就看不到 ADB 调试) ──
Say "第一步:打开`"开发者模式`""
Write-Host "小米电视默认把开发者相关的设置藏起来了,需要先把它显示出来。"
Write-Host ""
Write-Host "请拿遥控器按下面步骤操作:"
Write-Host "  ① 按遥控器上的【设置】键,进入【关于】(或【关于本机】)"
Write-Host "  ② 把光标停在【产品型号】(或【系统版本】)这一行上"
Write-Host "  ③ 连按遥控器中间的【确认键(OK键)】4 次"
Write-Host "  ④ 看到`"已进入开发者模式`"的提示就成功了"
Write-Host "     (个别机型是连按【菜单键】4 次;如果电视本来就能看到相关设置,本步可跳过)"
Write-Host ""
$a = Read-Host "操作好了吗?[回车=已打开,继续 / 输入 n=没反应,先退出]"
if ($a -eq "n") {
  Write-Host ""
  Write-Host "没关系,个别型号的进入方式略有不同。请告诉我您的电视型号,查到准确方法后再运行本向导。"
  exit 0
}

# ── 第二步:打开 ADB调试(开发者开关) ──
Say "第二步:打开`"ADB调试`""
Write-Host "开启开发者模式后,电视里才看得到这个开关。"
Write-Host ""
Write-Host "请拿遥控器继续操作:"
Write-Host "  ① 回到【设置】→【账号与安全】"
Write-Host "     (开启开发者模式后,有的电视会多出一个【开发者选项】菜单,去那里找)"
Write-Host "  ② 找到【ADB调试】,把它选成【允许】"
Write-Host "  ③ 如果弹出警告提示框,选【允许/确定】"
Write-Host ""
$a = Read-Host "操作好了吗?[回车=已打开,继续 / 输入 n=我还没找到,先退出]"
if ($a -eq "n") {
  Write-Host ""
  Write-Host "没关系。找到并打开后,重新运行本向导即可。"
  Write-Host "如果翻遍了都没有这个选项,告诉我电视型号,我帮你查准确位置。"
  exit 0
}

# ── 第三步:找到电视 IP 并连接 ──
Say "第三步:找到电视的 IP 地址并连接"
Write-Host "IP 地址就是电视在网络里的`"门牌号`",4 段数字用点隔开(如 192.168.1.25)。"
Write-Host "在电视上这样看:"
Write-Host "  【设置】→【关于】→【本机信息】(或【网络信息】),找`"IP地址`"那一行"
Write-Host "实在找不到也可以:登录路由器管理页(浏览器输入 192.168.1.1 或 192.168.0.1 试试),"
Write-Host "在`"已连接设备`"里找到您的电视名字,旁边就是 IP。"
Write-Host ""

function Test-Connected {
  $out = (& $script:ADB devices 2>$null) -join "`n"
  return ($out -like ("*" + $script:TVIP + ":5555*device*"))
}

$tryN = 0; $retrySame = $false
while ($true) {
  $tryN++
  if ($tryN -gt 5) { Write-Host "尝试次数有点多了,先退出。想清楚 IP 后重新运行向导。"; exit 2 }
  if (-not $retrySame) {
    $tv = Read-Host "请输入电视的 IP 地址(输 q 退出)"
    if ($tv -eq "q") { Write-Host "已退出。"; exit 0 }
    if ($tv -notmatch '^\d{1,3}(\.\d{1,3}){3}$') {
      Write-Host "  这串数字不像 IP——要 4 段数字、用点隔开,比如 192.168.1.25。请再看一眼电视,重新输入。"
      continue
    }
    $script:TVIP = $tv
    $script:SER  = "$tv`:5555"
  }
  Write-Host "  正在连接电视…"
  & $script:ADB connect $script:SER 2>$null | Out-Null
  Start-Sleep -Seconds 2
  if (Test-Connected) { break }
  Write-Host "  没连上。按顺序检查这三条:"
  Write-Host "    ① 【ADB调试】真的打开了吗?→【设置】→【账号与安全】→【ADB调试】→【允许】"
  Write-Host "    ② 电视和电脑在同一个网络吗?→ 电视连的 WiFi 和电脑连的要是同一个路由器"
  Write-Host "    ③ IP 有没有看错?→ 到【设置】→【关于】→【本机信息】再核对一遍"
  Write-Host "  (也有可能电视在待机——用遥控器按任意键把它叫醒)"
  Write-Host ""
  $a = Read-Host "  回车=再试一次 / 输 1=重新输入 IP / 输 n=退出"
  if ($a -eq "n") { Write-Host "已退出。处理好后重新运行向导即可,不会对电视有任何影响。"; exit 3 }
  if ($a -eq "1") { $retrySame = $false } else { $retrySame = $true }
}
$model = (& $script:ADB -s $script:SER shell getprop ro.product.model 2>$null)
$model = ($model | Select-Object -First 1)
if ($model) { $model = ("$model").Trim() }
Write-Host "  ✔ 连上了:$model(IP $($script:TVIP))"

# ── 人话对照表 ──
$DescMap = @{}
Get-Content $DescFile -Encoding UTF8 | ForEach-Object {
  if ($_ -and ($_ -notmatch '^#') -and $_.Contains("|")) {
    $cols = $_.Trim() -split '\|'
    $DescMap[$cols[0]] = $cols
  }
}
function DescOf($pkg, $col) {
  if ($DescMap.ContainsKey($pkg)) { return $DescMap[$pkg][$col - 1] }
  return ""
}
function Is-Installed($pkg) {
  $out = (& $script:ADB -s $script:SER shell pm list packages 2>$null) | ForEach-Object { ("$_").Trim() }
  return ($out -contains "package:$pkg")
}
function Test-Frozen($pkg) {
  $out = (& $script:ADB -s $script:SER shell pm list packages -d 2>$null) | ForEach-Object { ("$_").Trim() }
  return ($out -contains "package:$pkg")
}
# 收起:先 block,不行再 disable-user(两者都可在恢复模式找回)
function Freeze-Pkg($pkg) {
  & $script:ADB -s $script:SER shell pm block $pkg 2>$null | Out-Null
  Start-Sleep -Milliseconds 500
  if (Test-Frozen $pkg) { return $true }
  & $script:ADB -s $script:SER shell pm disable-user --user 0 $pkg 2>$null | Out-Null
  Start-Sleep -Milliseconds 500
  return (Test-Frozen $pkg)
}
function Unfreeze-Pkg($pkg) {
  & $script:ADB -s $script:SER shell pm unblock $pkg 2>$null | Out-Null
  & $script:ADB -s $script:SER shell pm enable $pkg 2>$null | Out-Null
  return (-not (Test-Frozen $pkg))
}

# 套餐1固定关闭的 13 项(广告/跟踪/推送)+ 单独询问的屏保
$AdPkgs = @(
  "com.xiaomi.mitv.advertise","com.miui.systemAdSolution","com.miui.tv.analytics",
  "com.xiaomi.devicereport","com.xiaomi.mitv.kuyun.acr","com.mitv.care",
  "com.xm.webcontent","com.duokan.videodaily","com.cmgame.gamehalltv",
  "com.xiaomi.gamecenter.sdk.service.mibox","com.xiaomi.mibox.gamecenter",
  "com.xiaomi.tv.appupgrade","com.xiaomi.mitv.upgrade"
)
$SSPkg = "com.xiaomi.mibox.lockscreen"

# ── 第四步:选套餐 ──
Say "第四步:选择优化套餐"
Write-Host "请输入数字后回车:"
Write-Host "  1) 温和优化 —— 只关闭广告和`"窥探`"类的功能,电视上原有节目应用全部保留(想省心选这个)"
Write-Host "  2) 极简安心 —— 在套餐1的基础上,把预装的购物/游戏/推广类应用也收起,电视更清爽"
Write-Host "  3) 全部恢复 —— 把之前优化时关掉的东西全部找回来,电视回到原状"
$m = Read-Host "套餐编号 [1/2/3,回车=1]"
if ($m -notin @("1","2","3")) { $m = "1" }

# ── 恢复模式直接执行 ──
if ($m -eq "3") {
  Say "恢复模式"
  Write-Host "正在找回所有被收起的功能和应用…"
  $frozen = (& $script:ADB -s $script:SER shell pm list packages -d 2>$null) | ForEach-Object { ("$_").Trim() -replace '^package:','' }
  foreach ($p in $frozen) {
    if (-not $p) { continue }
    $nm = DescOf $p 2; if (-not $nm) { $nm = $p }
    if (Unfreeze-Pkg $p) { Write-Host "  ✔ 已恢复:$nm" } else { Write-Host "  ✘ 恢复失败:$nm" }
    Start-Sleep -Milliseconds 500
  }
  Write-Host ""
  Write-Host "恢复完成。提醒:如果`"系统自动升级`"被恢复,电视以后可能自动升级,升级会重置之前做的优化。"
  exit 0
}

# ── 第五步:待机屏保 ──
Say "第五步:待机屏保"
Write-Host "待机屏保 = 电视闲着不动时轮播的图片(画面多为官方推广图)。"
$keepSS = $true
$a = Read-Host "保留待机屏保吗?[回车=保留 / 输入 n=关闭]"
if ($a -eq "n") { $keepSS = $false }

# ── 第六步:逐个确认预装应用 ──
Say "第六步:确认电视上的应用"
Write-Host "您自己安装的应用(直播、桌面等)一律原样保留,不会动。"
Write-Host "以下是电视预装的内容类应用(只在已安装的里面挑):"

$content = @()
foreach ($p in $DescMap.Keys) {
  if ($AdPkgs -contains $p) { continue }
  if ($p -eq $SSPkg) { continue }
  if (-not (Is-Installed $p)) { continue }
  $content += $p
}
$content = $content | Sort-Object
for ($i = 0; $i -lt $content.Count; $i++) {
  $n = $i + 1
  Write-Host "  $n) $(DescOf $content[$i] 2) —— $(DescOf $content[$i] 3)"
}

$removes = @(); $keeps = @()
$defaultAll = $false
if ($content.Count -gt 0) {
  if ($m -eq "2") {
    $defaultAll = $true
    Write-Host ""
    $a = Read-Host "套餐2默认把上面这些全部收起。想保留哪个就输编号(逗号分隔,回车=全部收起)"
    if ($a.Trim()) { $keeps = $a.Split(",") | ForEach-Object { $_.Trim() } }
  } else {
    Write-Host ""
    $a = Read-Host "想去掉哪个就输编号(逗号分隔,回车=全部保留)"
    if ($a.Trim()) { $removes = $a.Split(",") | ForEach-Object { $_.Trim() } }
  }
} else {
  Write-Host "  (这台电视上没有可挑选的预装内容应用)"
}

# ── 第七步:确认执行 ──
Say "第七步:开始优化"
Write-Host "即将执行:"
Write-Host "  · 关闭开机广告、首页推广、弹窗提醒、观看记录上传 等 13 项"
if (-not $keepSS) { Write-Host "  · 关闭待机屏保(按您的要求)" } else { Write-Host "  · 保留待机屏保" }
if ($content.Count -gt 0) {
  if ($defaultAll) { Write-Host "  · 收起预装内容应用(除您指定保留的)" }
  elseif ($removes.Count -gt 0) { Write-Host "  · 收起您选中的预装应用" }
}
Write-Host "  · 您自己装的应用一律不动"
Write-Host "(所有`"收起`"都只是暂停显示,随时可在恢复模式找回来)"
$a = Read-Host "确认执行?[回车=开始 / 输入 n=取消]"
if ($a -eq "n") { Write-Host "已取消,什么都没改。"; exit 0 }

# ── 执行 + 人话报告 ──
if (-not (Test-Path $BackupDir)) { New-Item -ItemType Directory -Force -Path $BackupDir | Out-Null }
$report = Join-Path $BackupDir ("优化报告_{0}.txt" -f (Get-Date -Format "yyyyMMdd_HHmm"))
$lines = @()
$lines += "============ 电视优化报告 $(Get-Date -Format 'yyyy-MM-dd HH:mm') ============"
$modeName = "温和优化"; if ($m -eq "2") { $modeName = "极简安心" }
$lines += "电视:$model(IP $($script:TVIP))  套餐:$modeName"
$lines += ""
$lines += "【本次优化做了什么】"

$okN = 0; $failN = 0
foreach ($p in $AdPkgs) {
  if (-not (Is-Installed $p)) { continue }
  $nm = DescOf $p 2
  Write-Host "  正在关闭:$nm…" -NoNewline
  if (Freeze-Pkg $p) {
    Write-Host " ✔"
    $lines += "  ✔ 已关闭:$nm —— $(DescOf $p 4)"; $okN++
  } else {
    Write-Host " ✘(跳过,不影响其他项)"
    $lines += "  ✘ 未成功:$nm"; $failN++
  }
}

$ssName = DescOf $SSPkg 2
if (Is-Installed $SSPkg) {
  if (-not $keepSS) {
    Write-Host "  正在关闭:$ssName…" -NoNewline
    if (Freeze-Pkg $SSPkg) {
      Write-Host " ✔"
      $lines += "  ✔ 已关闭:$ssName(按您的要求)"; $okN++
    } else {
      Write-Host " ✘"
      $lines += "  ✘ 未成功:$ssName"; $failN++
    }
  } else {
    Write-Host "  保留:$ssName(按您的要求)"
    $lines += "  · 保留:$ssName"
  }
}

$lines += ""
$lines += "【收起的应用(随时可恢复)】"
$hasRm = $false
for ($i = 0; $i -lt $content.Count; $i++) {
  $n = "$($i + 1)"; $p = $content[$i]
  $nm = DescOf $p 2; if (-not $nm) { $nm = $p }
  if ($defaultAll) {
    if ($keeps -contains $n) { Write-Host "  保留:$nm(按您的要求)"; $lines += "  · 保留:$nm"; continue }
    Write-Host "  正在收起:$nm…" -NoNewline
    if (Freeze-Pkg $p) { Write-Host " ✔"; $lines += "  ✔ 已收起:$nm —— $(DescOf $p 4)"; $hasRm = $true; $okN++ }
    else { Write-Host " ✘"; $lines += "  ✘ 未成功:$nm"; $failN++ }
  } elseif ($removes -contains $n) {
    Write-Host "  正在收起:$nm…" -NoNewline
    if (Freeze-Pkg $p) { Write-Host " ✔"; $lines += "  ✔ 已收起:$nm —— $(DescOf $p 4)"; $hasRm = $true; $okN++ }
    else { Write-Host " ✘"; $lines += "  ✘ 未成功:$nm"; $failN++ }
  }
}
if (-not $hasRm) { $lines += "  (无,按您的选择全部保留)" }

$userAppN = ((& $script:ADB -s $script:SER shell pm list packages -3 2>$null) | Where-Object { $_.Trim() }).Count
$lines += ""
$lines += "【保留的内容】"
$lines += "  · 您自己安装的应用共 $userAppN 个,全部原样保留"
$lines += ""
$lines += "【如何找回】"
$lines += "  随时可以恢复:重新运行本向导选`"3 全部恢复`",或对助手说`"把电视恢复原状`"。"
$lines += ""
$lines += "【技术备注(可忽略)】"
$lines += "  成功 $okN 项,未成功 $failN 项;以上`"收起`"通过系统冻结实现,未删除任何文件。"
$lines += "============================================"

$lines | Out-File -FilePath $report -Encoding UTF8
Say "完成!"
$lines | ForEach-Object { Write-Host $_ }
Write-Host ""
Write-Host "报告已保存到: $report"

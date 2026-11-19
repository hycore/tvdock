# 小米电视优化 Skill(AI 用)

> 适用:MIUI TV 1.3.x(Android 4.4.4)与 MIUI TV for Android 9(SDK 28)小米电视/盒子
> 已验证机型:小米电视 3S 48"(hancock,Android 4.4.4)、小米电视 MiTV-ASTP0(Android 9)
> 安全性:所有操作可逆——旧系统 `pm unblock`/`pm enable`,Android 9+ `cmd package install-existing` 找回(见 `_freeze.sh` 版本感知链);不碰系统核心

## 第一原则:AI 执行一切,用户只回答问题

**本 skill 的消费者是 AI(agent),不是终端用户。**

- 所有命令由 AI 在**自己的运行环境**里执行;用户设备上什么都不用装(连 adb 都装在 AI 的机器上)
- 用户全程只需要回答问题:"选哪个套餐""屏保要不要""这些应用留哪些"
- 对用户说话**禁止术语**:不说 adb / 包名 / pm block / 冻结 / shell,只说"小工具 / 收起 / 找回 / 电视的 IP"
- 面向终端用户的向导脚本(tv_wizard.sh/.bat)只是**可选自助通道**,不是主流程

## 何时使用本 Skill

- 用户要求"关闭小米电视广告 / 精简系统 / 清理电视"
- 用户要求"安装 TVDock / 小橙子"等增强功能
- 用户报告"ADB 连接不上 / 自动断开"
- 用户报告"每次安装都需要人工确认"

## AI 环境准备(AI 自己的机器,无需用户参与)

```bash
# AI 首次使用时自检并自动安装 adb(Google→腾讯镜像自动回退;macOS/Linux/Windows 通用)
bash scripts/env_check.sh --install
```

adb 装在 skill 自带 `bin/platform-tools/`,后续脚本自动识别,无需配 PATH。
电视侧要求(需要引导用户完成,见对话流程第 1~2 步):电视开机、开启 ADB 调试。

## 傻瓜模式:AI 对话流程(默认流程,严格按序执行)

### 第 1 步:引导用户开"开发者模式"(必做前置,小米电视默认隐藏开发者入口)

对用户说:"小米电视默认把开发者设置藏起来了,要先把它显示出来",步骤:

> 遥控器【设置】→【关于】(或【关于本机】)→ 光标停在【产品型号】(或【系统版本】)那一行 → **连按遥控器中间的【确认键(OK键)】4 次** → 看到"已进入开发者模式"提示即成功
> 个别机型是连按【菜单键】4 次;若电视本来就能看到相关选项,本步可跳过

用户试了没反应时:请用户报电视型号,帮查准确进入方式。

### 第 2 步:引导用户开"ADB调试"

对用户说:"开启开发者模式后,才能看到这个开关",步骤:

> 遥控器【设置】→【账号与安全】(开完开发者模式有的电视会多出【开发者选项】菜单,去那里找)→【ADB调试】→ 选【允许】;弹出的警告框选【允许/确定】

用户找不到该选项时:请用户报电视型号,再帮查准确位置。

### 第 3 步:引导用户找电视 IP

对用户说:"IP 是电视在网络里的门牌号,4 段数字用点隔开(如 192.168.1.25)",位置:

> 【设置】→【关于】→【本机信息】(或【网络信息】),找"IP地址"那一行
> 实在找不到:登录路由器管理页(192.168.1.1 或 192.168.0.1),在"已连接设备"里找电视名字

拿到 IP 后 AI 执行 `adb connect <IP>:5555`。

- IP 格式不对:温和指出"要 4 段数字用点隔开",请用户重新看一眼电视,**不要退出对话**
- **首次连接预告(Android 5+ 必有)**:第一次连接前先告诉用户:"电视屏幕上马上会弹一个'是否允许调试'的框,请勾选'始终允许',再点'允许/确定'"。`adb devices` 显示 `unauthorized` 就是在等这一步,引导用户点完即可,授权一次后不再重复弹
- 连不上:只说四条检查 ①ADB调试真的打开了吗 ②电视和电脑是同一个路由器/WiFi 吗 ③IP 核对了吗 ④**电视刚重启过吗——部分机型重启会把 ADB 开关自动关掉,重新打开即可**;补一句"也可能是电视在待机,用遥控器按任意键叫醒它"。重试 ≥2 次仍失败才建议用户稍后再来
- 成功后执行 `adb shell getprop ro.product.model` 拿型号,向用户确认:"已连上您的 XXX 电视"

### 第 4 步:问套餐 + 屏保(一次问完)

用提问组件一次问两个问题:

**问题 1 · 优化套餐**(单选):
- **温和优化(推荐)**:只关闭广告和"窥探"类功能(开机广告、首页推广、观看记录上传等 13 项),原有节目应用全部保留
- **极简安心**:温和优化的全部内容 + 把预装的购物/游戏/推广类应用收起,电视更清爽

**问题 2 · 待机屏保**(单选):"电视闲着时轮播的图片(多为官方推广图)"→ 保留 / 关闭

### 第 5 步:逐应用确认保留

AI 先扫描真实状态:`adb shell pm list packages`,按 `scripts/pkg_desc.txt` 过滤出**实际安装**的内容类应用。

向用户展示时用 pkg_desc 的人话名,逐个确认:

> "电视上发现这些预装应用:
> 1. 银河奇异果(爱奇艺TV版)—— 在线视频
> 2. 乐播投屏 —— 手机投屏到电视
> 3. 小米商城 —— 电视购物
> 您想保留哪几个?(可多选)
> 另外说明:您自己安装的应用(直播、桌面等)一律不动。"

- 温和优化:默认全部保留,用户点名才收起
- 极简安心:默认全部收起,用户点名才保留
- 用户说"保留"就保留,说"去掉"才去掉;含糊时复述一遍让用户确认

### 第 6 步:执行(AI 自己做,逐项验证)

使用版本感知冻结链(`scripts/_freeze.sh`,每级执行后验证,失败自动降级):

```bash
source scripts/_freeze.sh
freeze_pkg <包名>   # Android 9+ 走 pm uninstall --user 0(持久)→ disable-user 降级
                    # API 24~27 走 pm suspend → disable-user
                    # 旧系统走 pm disable-user → pm block
```

每项之间 `sleep 0.5`。执行时向用户用人话播报进度:"正在关闭:开机广告… ✔"。
失败的项继续执行下一项,最后告知:"这一项没成功,但不影响其他"。

> ⚠️ Android 9+(SDK 28)实机结论:`pm block` 命令不存在;`pm suspend` 在小米电视重启后**不持久**。
> 广告类组件一律以 `pm uninstall --user 0` 为准(跨重启持久,`cmd package install-existing` 随时找回)。

### 第 7 步:人话报告(必须)

对话里完整展示,并存档到 `backups/优化报告_<时间>.txt`:

- **本次优化做了什么**:每项一句效果("开机直接进画面,更快""不再上传观看记录")
- **保留了什么**:"您自己安装的 N 个应用全部原样保留""待机屏保(按您的要求)"
- **收起了什么**:每项附影响("爱奇艺节目无法观看")
- **如何找回**:"随时说'把电视恢复原状'"

### 用户反悔:全部恢复

AI 执行 `bash scripts/tv_rollback.sh <电视IP>`(已覆盖全状态:block/suspend/disable/uninstall)。
单项手动恢复按冻结方式对应:`pm unblock` / `pm unsuspend` + `pm enable` / Android 9+ 卸载的用 `cmd package install-existing <包名>` 找回。完成后提醒:"系统自动升级后,电视可能自动升级,升级会重置之前的优化。"

## 可选:终端自助向导(用户想自己动手时才提)

- macOS/Linux:`bash scripts/tv_wizard.sh`
- Windows(无任何环境):双击 `scripts\tv_wizard.bat`(PowerShell 版,Windows 自带)
- 流程与 AI 对话一致;用户没主动要求时**不要**把用户推向脚本

## 高级操作(脚本清单,均以电视 IP 为第一参数)

| 脚本 | 用法 | 功能 |
|---|---|---|
| `env_check.sh` | `bash scripts/env_check.sh [--install]` | AI 环境自检 + adb 跨平台自动安装 |
| `tv_status.sh` | `bash scripts/tv_status.sh <电视IP>` | 冻结包/第三方包/总包数总览 |
| `tv_ads_off.sh` | `bash scripts/tv_ads_off.sh <电视IP>` | 一键冻结 17 个广告/遥测组件(13 基础 + 4 深查补删) |
| `tv_rollback.sh` | `bash scripts/tv_rollback.sh <电视IP>` | 一键解冻全部 blocked 包 |
| `tv_install.sh` | `bash scripts/tv_install.sh <电视IP> <apk路径>` | 静默安装(uiautomator 自动点确认) |
| `adb_keepalive.sh` | `bash scripts/adb_keepalive.sh <电视IP>` & | ADB 心跳保活+断线重连 |
| `accept.sh` | `bash scripts/accept.sh <电视IP> <apk路径>` | 小橙子 A1~A7 自动化验收 |
| `pkg_desc.txt` | (对照表,禁止硬编码描述) | 包名 → 人话名/是什么/关掉后影响 |
| `tv_wizard.sh` / `tv_wizard.bat` + `.ps1` | 见上节 | 终端自助向导 |

## 连接管理(AI 端)

```bash
adb connect <电视IP>:5555   # 5555 为 ADB 默认端口
# 电视休眠会断开:重试或请用户按遥控器唤醒
adb disconnect; sleep 1; adb connect <电视IP>:5555
# 长任务建议先起保活
bash scripts/adb_keepalive.sh <电视IP> &
```

## 已知坑(实机踩过,必须规避)

### 坑 1:/system 与 /data 双路径包

`adb shell pm path <包名>` 可能返回**两条路径**(同一包名同时存在于 /system/app/ 和 /data/app/):

- /system 路径的包受系统保护:`pm block` 可能报 SecurityException 或静默失败
- 对策:先 `pm block`,验证失败立即退 `pm disable-user --user 0`,再验证
- 仍失败的包标记"不可收起",**如实告知用户这一项动不了**,绝不谎报成功
- 判断某包能不能动:不要看路径猜,直接执行后用 `pm list packages -d` 验证结果

### 坑 2:重启后修改不生效(PackageManager 写入静默失败)

连续重启电视、或系统正忙时,PackageManager 的状态写入会**静默失败**——`pm block` 返回空、当场验证还是 true,但重启后全部回原样:

- 预防:批量操作前确认系统就绪——`adb shell getprop sys.boot_completed` 必须为 `1`
- 检测:批量冻结结束后统计"当场验证通过数";执行了 N 项但通过数异常少,即判定为 PM 写入失败
- 恢复:**让用户手动重启一次电视**(遥控器或断电重启均可,重置 PackageManager),等开机完成后**重新执行同一批操作**——所有脚本幂等,重跑无副作用
- 最终验证:重跑后再抽查 `pm list packages -d`,并向用户复述实际生效清单,而不是复述"执行过的"清单

### 坑 3:Android 9 电视(MiTV-ASTP0 实测)没有 `pm block`

- `pm block` 返回 `Unknown command: block`(该子命令仅存在于旧版 MIUI TV/Android 4.4)
- 对策:按 SDK 分档选首选命令(`_freeze.sh` 已实现)——SDK≥28 直接 `pm uninstall --user 0`(实测 suspend 在小米电视**重启后不持久**,5 个包全部复活;卸载则跨重启持久);SDK 24~27 用 `pm suspend`;更旧用 `pm disable-user`/`pm block`。每级执行后验证,失败自动降级

### 坑 4:漏网组件排查 + 开机广告"复活"误判

- 用户报"开机还有广告"≠ 开机广告组件回来了:启动阶段会临时拉起存活的推广组件(如 duokan.videodaily)
- 深查曾发现 4 个漏网遥测/推送组件(miui.analytics/tvpush/healthdiagnosis/cloudcontrol),已入清单补删(现共 17 项)
- 判定口诀:先 `pm path` 确认组件在不在 → 在 = 没删干净;不在 = 看启动阶段还有谁在拉起(重跑 skill 即可)
- **gamecenter / upgrade 两组件会被开机流程自动重装**(区别于"临时拉起"):重启后 `pm path` 又能查到。不是 skill 失效,重跑一遍即可;根治需路由器 DNS 屏蔽上游下载源(`docs/广告域名清单-路由器DNS屏蔽.txt`)

### 坑 5:/vendor 分区包 suspend/disable 均拒绝

- 部分包(如 com.miui.systemAdSolution)位于 /vendor 分区:`pm suspend` 与 `pm disable-user` 都报权限拒绝
- 对策:`pm uninstall --user 0` 对 /vendor 包同样生效(隐藏用户副本)
- 边界:系统分区文件仍在,恢复出厂或 OTA 会回归——届时重跑本 skill 即可

### 坑 6:AdGuard 私人 DNS(DoT)整机屏蔽在大陆网络不可达

- `settings put private_dns_mode hostname` + `dns.adguard.com` 后,电视**所有**域名解析失败(baidu 也 unknown host)
- 根因:大陆网络到境外 AdGuard DoT 不通
- 处置:**立即回滚** `settings put private_dns_mode off`;域名屏蔽改走**路由器端**(AdGuard Home/OpenWrt,清单见 `docs/广告域名清单-路由器DNS屏蔽.txt`)
- 规矩:改 DNS 类设置必须当场用 `ping` 验证连通性,失败立即回滚,不留"整机断网"的电视给用户

### 坑 7:/etc/hosts 只读,本机 hosts 屏蔽不可行

- `/etc/hosts` 属 root,系统分区只读;`adb root` 在生产固件被拒("adbd cannot run as root in production builds")
- 结论:非 root 电视本机 hosts 方案不可行,与坑 6 同走 DNS 层(路由器端)替代
- 另注意:App 内业务广告(如奇异果贴片、GITV 服务端贴片)来自**内容服务端**,系统层清理无法去除,要向用户如实说明边界

### 坑 8:Android 5+ 首次连接要在电视上确认 RSA 授权

- 首次 `adb connect` 后设备状态为 `unauthorized`,电视屏幕弹"是否允许调试?"——用户必须勾选"始终允许"再点"允许/确定"
- 授权信息存在电视端(`adb_keys`),之后重连不再弹;只有换电脑/重置调试授权才会重新出现
- Android 4.4 时代无此机制,所以老机型上观察不到——**不要以老机经验判断新机型**
- 脚本层:`_common.sh` 的 `tv_gate` 与双向导均已识别 unauthorized 并给出人话指引

### 坑 9:部分机型重启后 ADB 开关被自动重置(实测 Android 9 小米电视)

- 现象:重启电视后 `adb connect` 拒绝/offline,进设置一看,**ADB调试开关被系统自动关掉了**——必须人工重新开启
- 话术:"重启后电视可能把 ADB 开关自动关了,请到【设置→账号与安全→ADB调试】重新打开"
- 影响与对策:这是系统行为,无法从 ADB 侧根治(开关关闭时 adb 通道本身就不通);skill 的应对是**把这条写进所有连接失败排障的第一梯队**,并在长任务前提醒用户"期间如果重启过电视,重连前先确认开关还开着"
- 关联:重启还会连带触发 RSA 授权重弹的误判(见坑 8,授权其实仍在,只是开关被关)——先查开关,再查授权

## 执行规则(AI 必须遵守)

1. **每个 adb 命令前检查连接**:电视休眠时端口关闭,需重试或引导用户唤醒
2. **`pm block` 可能静默失败**:执行后必须 `pm list packages -d` 验证;失败退 `pm disable-user --user 0`;批量操作前后各统计一次生效数,生效数与预期不符时按"已知坑 2"重启电视后重跑
3. **批量操作每步 sleep 0.5**:避免系统响应不及时丢命令
4. **安全守卫**:自动点确认框时,检测到"删除/卸载"字样必须跳过(tv_install.sh 已内置)
5. **可逆性优先,方式按系统版本选**:旧系统(Android 4.4)用 `pm block`/`disable-user` 收起即可;Android 9+(坑 3)广告组件必须 `pm uninstall --user 0` 才持久——同样是可逆的(`cmd package install-existing` 找回),向用户说明"随时可找回"
6. **不动系统核心**:直播播放框架、设置、遥控、帐号(PACKAGES.md 红色区)
7. **包名只出现在执行和报告文件里**,对用户说话一律用人话名
8. **安装确认必须提前告知**:电视上安装任何应用都会弹确认框(安全设计,无法绕过)。AI 应提前说"等下电视上会弹一个确认框,您按一下'继续安装'就行";用 tv_install.sh 时自动守护点击,失败则请用户手动按

## 验证与回滚(AI 端)

```bash
SER=<电视IP>:5555
adb -s $SER shell pm list packages -d          # 被收起的包(disable)
adb -s $SER shell pm list packages             # 核对卸载的包是否还在(--user 0 卸载后 pm path 为空)
adb -s $SER shell pm unblock <包名>            # 恢复单项(block)
adb -s $SER shell pm unsuspend <包名>          # 恢复单项(suspend)
adb -s $SER shell pm enable <包名>             # 恢复单项(disable-user)
adb -s $SER shell cmd package install-existing <包名>   # 找回被 uninstall --user 0 的包(Android 9+)
bash scripts/tv_rollback.sh <电视IP>           # 一键全部恢复(全状态覆盖)
```

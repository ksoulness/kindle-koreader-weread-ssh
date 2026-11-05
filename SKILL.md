---
name: kindle
description: Kindle Paperwhite 3（KPW3 / Paperwhite3）的管理与设置：SSH 接入（KOReader 内置 2323 主用 + KOSSH 2222 兜底，root 空密码免密）、KOReader 四插件管理（微信读书/番茄/Legado/Leko，含菜单 id 与大小写坑）、菜单重排（menu_order + plugins_disabled 根因）、原生微信读书（Isword 0.3.9，KUAL 启动）、KOReader 升级（kindlepw2 包）、垃圾清理。用户说「连 kindle」「kindle ssh」「微信读书没了」「legado 不见了」「番茄在哪」「koreader 菜单没有某插件」「清理 kindle 垃圾」「koreader 升级」「kindle 连不上」「weread 恢复未完成」时使用。
metadata:
  scope: personal-local-dsh
  host: DESKTOP-JCAJDQ3
---

# Kindle PW3 管理与设置

本机专属（Windows `DESKTOP-JCAJDQ3`）。设备信息、SSH 入口、插件与菜单操作、踩坑清单。换机不继承路径。

## 设备速查

| 项 | 值 |
| --- | --- |
| 型号 | Kindle Paperwhite 3（KPW3 / Paperwhite3） |
| 固件 | `5.12.2 (356962 025)`（**<5.16.3 ⇒ 必须 kindlepw2 包**） |
| 内核 | `Linux 3.0.35-lab126 armv7l`，**无 IPv6**（`/proc/sys/net/ipv6` 不存在） |
| USB 卷 | Kindle 内部存储（MTP，Windows 盘符 `H:`，FAT32，1 GB） |
| KOReader | v2026.07.1（模型 KindlePaperWhite3；luajit 在 `/mnt/us/koreader/luajit`） |
| 局域网 IP | `192.168.0.145`（DHCP，**会变**；连不上先扫 2222/2323 定位） |
| 原生微信读书 | Isword 0.3.9（`AppID tech.isword.weread.test`，KUAL 启动，不依赖 KOReader） |

## SSH 接入（两个入口）

**连接模板**（root 是空密码，必须带这组认证参数，否则 `Permission denied`）：

```bash
SSHOPTS="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=8 \
  -o PreferredAuthentications=password -o PubkeyAuthentication=no -o LogLevel=ERROR"

ssh -p 2323 $SSHOPTS root@192.168.0.145 '<cmd>'      # 内置 SSH，主用
scp -P 2323 $SSHOPTS <local> root@192.168.0.145:<path>  # 注意 scp 用大写 -P
```

| 端口 | 是谁 | dropbear 版本 | 启动方式 | 说明 |
| --- | --- | --- | --- | --- |
| **2323** | KOReader 内置 SSH 插件 | 2026.92 | 齿轮→网络→SSH server 开关 | **主用**；本机因 KOSSH 占了 2222 才把 `settings.reader.lua` 的 `SSH_port` 改成 `"2323"` 避让 |
| **2222** | KOSSH（KUAL 扩展） | 2018.76 | KUAL→Tools→Start KOSSH | 兜底；关机/重启后**不会自启**，要重新点 |

- 内置 SSH 插件路径 `/mnt/us/koreader/plugins/SSH.koplugin/main.lua`（builtin，`pluginloader.lua:26` 含 `["SSH"]=true`）。
- 内置 SSH 的 `SSH:start()` 命令：`./dropbear -E -R -p <port> -P /tmp/dropbear_koreader.pid`；菜单勾 `Login without password` 才加 `-n`（否则空密码被拒）。
- **两个 dropbear 会抢端口**：KOSSH 启动时若 KOReader 内置已监听同端口，KOSSH bind 失败；反之亦然。别同时开同一个端口。
- **僵尸 dropbear 坑**：关掉 KOReader 不杀已启动的 dropbear daemon，`2222` 可能被已退出的 KOReader 留下的 dropbear 占用（`Connection closed` 握手失败 = 服务器无主机密钥 `settings/SSH/` 空）。
- IP 变了怎么找：`ssh-keyscan` 拿不到 key 是正常的（无密钥），扫全段 2222/2323 端口定位。

## 四个阅读插件（tools 组顺序）

| 插件 | 菜单 id（**大小写敏感**） | 来源/版本 | 入口说明 |
| --- | --- | --- | --- |
| 微信读书 | `weread` | finlater/weread.koplugin v1.7.0 | 工具菜单单入口，走 Web 接口；登录需手机 App 拿 API Key + 扫码 |
| 番茄小说 | `fanqie` | hesan1232 v2.16.36 | 走官方 App reading 协议，免书源 |
| Legado 书目 | **`Legado_main`（大写 L！）** | pengcw/legado.koplugin v1.2.3 | `sorting_hint="search"`；连手机「阅读3.0」Web 服务 |
| Leko | `leko` | jnjnnjzch v0.16.0 | 纯本地 QuickJS，文件管理器顶栏书架图标 |

- tools 组目标顺序：`"weread", "fanqie", "Legado_main", "leko"`。
- **大小写坑（本 session 实测踩过）**：`menu_order.lua` 里写的 id 必须与插件注册的 key **逐字符精确匹配**。把 `Legado_main` 写成小写 `legado_main` → 排序规则静默跳过 → legado 按自身 `sorting_hint="search"` 落到「搜索」标签而不是「工具」标签。症状 =「第三个工具栏里 legado 不见了」。

## 菜单机制（KOReader v2026.07.1）

- 文件管理器顶部 5 标签：`filemanager_settings`(1) / **setting 齿轮(2)** / **tools(3)** / **search(4)** / main。阅读器 7 标签（多 navi/typeset）。
- 排序文件：`settings/filemanager_menu_order.lua` + `settings/reader_menu_order.lua`（存在则整体覆盖 factory 默认 order）。
- `order["KOMenu:disabled"]` 里的 id 从菜单移除；`more_tools` 组 = 工具菜单第二页。
- 无 `sorting_hint` 且不在 order 里的项 = orphan，加 `"NEW: "` 前缀塞进第一个菜单。
- **「某插件菜单项不显示」排查顺序（本 session 根因）**：
  1. 先查 `settings.reader.lua` 的 `plugins_disabled` 表——`["SSH"]=true` 这类禁用会让插件不加载、菜单项直接消失，且**源码/配置层都看不出问题**；
  2. 再查 menu_order 里 id 大小写是否与插件注册 key 精确匹配；
  3. 最后才怀疑插件文件缺失。
- **改 `settings.reader.lua` 前必须先退出 KOReader**：它退出时会把内存里的配置写回文件，直接改会被覆盖。
- 改完 menu_order 要**重启 KOReader** 才生效（菜单在启动时构建一次）。

## 原生微信读书（Isword 0.3.9）

- 布局：`/mnt/us/weread/`（主程序，含 `bin/kindlepw2/weread_ui` 等 7 个 armhf 静态 ELF）+ `fonts/`（55M，必须整带）+ `documents/微信读书*.sh` + `extensions/weread/`（KUAL 入口）。
- KUAL 三按钮：Start WeRead / WeRead compatibility report / Restore launch state。
- **「正在检查上次未完成的恢复…恢复尚未完成」= 残留 run 目录未清**：`/mnt/us/weread/runs/<ts>/` 里 `session.log` 末行 `event=restore_done` 说明恢复实际已完成，只是标记没清。处理：确认 `ps` 无 weread 进程 → 删掉该 run 目录（或改名 `.bak` 留回滚）。

## 垃圾清理

| 目标 | 说明 |
| --- | --- |
| `/mnt/us/koreader_old_*` | KOReader 升级时留下的旧版本备份，**最大头**（本机实测 125.8M） |
| `/mnt/us/fbcap/` | 帧缓冲 dump（fb.raw，1.5M），纯垃圾 |
| `/mnt/us/weread/runs/<ts>.*` | 残留 run 目录/lock，`ps` 无 weread 进程且 `restore.*.done` 齐全即可删 |
| `/tmp/*.bak*` | 修复过程备份，重启自动清空 |

清完用 `df -h /mnt/us` 核对（1 GB 总量）。

## KOReader 升级

- **固件 <5.16.3 必须用 `koreader-kindlepw2-*.zip`**，不能用 `kindle`/`kindlehf` 包（会起不来）。
- 原地换目录：整包落 `koreader_new` → 补齐 settings/cache/patches/用户插件 → `koreader` 改名 `koreader_old_<date>` → `koreader_new` 改名 `koreader`。
- MTP 卷 robocopy 递归拷小文件目录会卡死，逐文件 Copy-Item。

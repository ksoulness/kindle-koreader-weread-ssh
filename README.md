# Kindle Paperwhite 3 越狱 + KOReader + 微信读书 + SSH 接入

KPW3（Paperwhite 3，固件 `<5.16.3`）改写整机、装 KOReader 插件、开 SSH 的完整经验，含踩坑与根因定位。

**主线顺序**：① 电脑连接 → ② 开 KOReader 内置 SSH → ③ 打不开就装 KOSSH 兜底 → ④ 用 KOSSH 激活 KOReader 内置 SSH。

> 实测时间 **2026-11-05**。设备：Kindle Paperwhite 3，固件 `5.12.2 (356962 025)`，内核 `Linux 3.0.35-lab126 armv7l`（**无 IPv6**），KOReader v2026.07.1，局域网 IP `192.168.0.145`（DHCP，会变）。

## 目录

| 文档 | 内容 |
|---|---|
| [01-电脑连接](docs/01-电脑连接.md) | USB/MTP 连接、盘符、文件拷贝的坑 |
| [02-开启KOReader内置SSH](docs/02-开启KOReader内置SSH.md) | 内置 SSH 的正确打开方式、连接命令、排障 |
| [03-KOSSH兜底激活](docs/03-KOSSH兜底激活.md) | 内置打不开时装 KOSSH，再用它激活内置 |
| [04-微信读书与阅读插件](docs/04-微信读书与阅读插件.md) | 微信读书 / 番茄 / Legado / Leko 四插件 |
| [05-KOReader升级](docs/05-KOReader升级.md) | v2025.08 → v2026.07.1，kindlepw2 包选择 |
| [06-菜单优化手册](docs/06-菜单优化手册.md) | 重排 / 隐藏 / 下沉第二页 / 调出 SSH |
| [07-Reeden](docs/07-Reeden.md) | Flutter 独立阅读器（非 KOReader 插件，KUAL 启动） |
| [08-垃圾清理与SSH装软件](docs/08-垃圾清理与SSH装软件.md) | 清 cr3cache 腾空间 + SSH tar/pscp 装软件（替代 USB MTP） |
| [09-Reader3部署](docs/09-Reader3部署.md) | NAS 部署：docker-compose/环境变量/书源服务/Cloudflare 公网 |
| [10-Reader3用户与同步](docs/10-Reader3用户与同步.md) | 新增用户 + Kindle/手机/网页三种同步方式 |
| [11-Legado自动换源补丁](docs/11-Legado自动换源补丁.md) | 死源书自动换源，解决 chapter list empty / 目录为空 |
| [12-踩坑清单](docs/12-踩坑清单.md) | 书源不同步/换源/死源等 15 条踩坑 |
| [13-防休眠](docs/13-防休眠.md) | 临时防休眠 keepalive 脚本，SSH 不断网 |
| [packages/](packages/README.md) | 安装包归档：原生微信读书 + 四插件 + Reeden + Leko 书源订阅模块（离线可用，sha256 已校验） |
| [番茄书架分组补丁](packages/plugins/fanqie-bookshelf-groups-v2.16.36/README.md) | v2.16.36 的分组筛选补丁、原文件备份和恢复方法 |
| [Legado 自动换源补丁包](packages/plugins/legado-autosource/README.md) | reader3.lua 补丁版 + 原始版，死源书自动换源 |
| [SKILL.md](SKILL.md) | DSH 技能：Kindle 管理与设置（SSH 接入 / 四插件 / 菜单重排 / 垃圾清理，触发词驱动） |

## 一句话结论

1. **固件 `<5.16.3` 必须用 `kindlepw2` 包**，不能用 `kindle`/`kindlehf` 包。
2. **SSH 用 KOReader 内置的就行**（齿轮 → 网络 → SSH server），不需要另装 KOSSH。
3. **「菜单里没有 SSH」的唯一根因 = 插件被禁用**：`settings.reader.lua` 里 `plugins_disabled["SSH"]=true`。先查这个，别瞎找，更别急着装 KOSSH。
4. **root 是空密码**，连接必须带 `PreferredAuthentications=password -o PubkeyAuthentication=no`，否则 `Permission denied`。
5. **内核无 IPv6 不需要 patch**：dropbear 2026.92 用 `-p 纯端口` 直接监听 IPv4（实测推翻「必须绑 0.0.0.0」）。

## SSH 连接速查

```bash
ssh -p 2222 \
  -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
  -o ConnectTimeout=8 \
  -o PreferredAuthentications=password -o PubkeyAuthentication=no \
  -o LogLevel=ERROR \
  root@192.168.0.145
```

- 默认端口 `2222`（本机因装了 KOSSH 才把内置改成 2323 避让，详见文档 02/03）。
- 进 shell 后 `id` 应回 `uid=0(root) gid=0(root)`。

## 设备档案

| 项 | 值 |
|---|---|
| 型号 | Kindle Paperwhite 3（KPW3 / Paperwhite3） |
| 固件 | `5.12.2 (356962 025)`（<5.16.3 ⇒ kindlepw2 包） |
| 内核 | `Linux 3.0.35-lab126 armv7l`，无 IPv6 |
| USB 卷 | Kindle 内部存储（MTP，Windows 下 `H:`，FAT32，1 GB） |
| KOReader | v2026.07.1（模型 KindlePaperWhite3） |
| 局域网 IP | `192.168.0.145`（DHCP） |
| SSH | 内置 dropbear 2026.92（正确路径默认 2222）；KOSSH dropbear 2018.76 仅作兜底 |

# 07 · Reeden 阅读器（Flutter 独立 App）

Reeden 是独立于 KOReader 的 Flutter 阅读器，直接跑在 Kindle framebuffer 上。**不是 KOReader 插件**，与原生微信读书一样走「越狱 + KUAL 启动」路线。

## 定位与机型支持

- 官方三档：推荐（Oasis 2 及以后）、**有限支持（PW3 / Voyage / Oasis 1 / Kindle 8）**、不建议（PW2 / Kindle 7 及更旧）。
- 本机 KPW3 属「有限支持」：**EPUB 没问题，PDF 和大内存书籍会吃力**（512MB 内存 + 3.0 老内核的硬件限制，不是安装问题）。
- 与 KOReader 互斥：两者都是全屏 framebuffer App，**不能同时跑**，必须先退出 KOReader 再启动。

## 安装

zip 见 [packages/Reeden-kindle.zip](../packages/Reeden-kindle.zip)。三个目录合并复制到 USB 根 `/mnt/us/`：

| 目录 | 内容 |
|---|---|
| `reeden/` | 主程序：`reeden/reeden/reeden-kindle` + Flutter 引擎（`lib/libapp.so` 62.7MB + `lib/libflutter_engine.so`）+ `lib/glibc/` 与 `lib/glibc-legacy/` 自带 glibc |
| `extensions/reeden/` | KUAL 菜单项（config.xml / menu.json / start.sh） |
| `documents/Reeden.sh` | 首页「书」启动脚本（需 KPM；无 KPM 时走 KUAL 菜单） |

启动入口：

- **KUAL → Reeden → Reeden（reeden）**（本机方式，因为没装 KPM）。
- 首页「Reeden 书」只在装了 KPM（Kindle Package Manager）时出现。
- 退出：我的 → 右上角 / 底部「退出 Reeden」→ 回到 Kindle 主页。
- 第一次启动要等加载；若闪退回主页，多半是机型/固件不匹配，看日志 `reeden/reeden/reeden.log`。

## 兼容性自动检测（run.sh）

`reeden/reeden/run.sh` 启动时自动检测，日志写入 `reeden/reeden/reeden.log`：

| 项 | 检测逻辑 | 本机 KPW3 结果 |
|---|---|---|
| glibc 模式 | 系统 glibc≥2.18 且硬浮点 → system；内核<3.2 → legacy；否则 bundled | **legacy**（内核 3.0.35，且无 `/lib/ld-linux-armhf.so.3` 硬浮点 ld） |
| 省内存 | 内存<700MB 且 MODE=system 且 upstart | **不支持**（legacy 模式），退化为 pause UI（`killall -STOP awesome`） |
| init 类型 | `/etc/upstart` 存在 | upstart |

- `reeden/reeden/glibc-required` 声明 `GLIBC_2.18`；本机系统 glibc 2.20 满足版本但缺硬浮点 ld，所以走 legacy 自带 glibc（Debian jessie 2.19 + 老内核 DT_JMPREL 补丁，专为 kernel<3.2 准备）。
- 502MB 内存 < 700MB 会触发低内存默认值，但 legacy 模式不支持「停框架省内存」，只会 pause UI（对 EPUB 阅读够用）。

## 卸载

删除 USB 根目录下三个位置：

- `reeden/`（⚠️ 书、笔记和设置都在 `reeden/home/` 里，删前先在 Reeden 里备份或同步）
- `extensions/reeden/`
- `documents/Reeden.sh`（及自动生成的 `documents/Reeden.sdr`）

## 更新

Wi-Fi 下 Reeden 会提示新版本，也可「我的 → 设置 → 关于 → 检查更新」。升级 zip 结构相同，替换 `reeden/reeden/` 目录即可，旧版自动挪到 `reeden/reeden.old`（`.update/` 目录里留存更新状态）。

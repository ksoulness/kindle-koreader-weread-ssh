# 05 · KOReader 升级

KPW3 从 v2025.08 升到 v2026.07.1，以及「为什么必须选 kindlepw2 包」。

## 选包（最关键的一步）

KPW3 固件 **`5.12.2` < `5.16.3`**，必须用 **`kindlepw2`** 包：

- ✅ `koreader-kindlepw2-v2026.07.1.zip` — sha256 `ea1f575c54492a2c679d128b7f3210fd7d6a87e5f5a1ff1f7a7fe2080ff68f86`
- ❌ `koreader-kindle-v2026.07.1.zip` — sha256 `1fa9cc2784ffa42eaa309445d4e81661f825614c9c32349554fed6e4c8757a1d`（**误下过，已删**）
- ❌ `koreader-kindlehf-*.zip` — 给 newer 固件

判定依据：`H:\system\version.txt` = `Kindle 5.12.2 (356962 025)`。`<5.16.3` 走 kindlepw2，`≥5.16.3` 才走 kindle/kindlehf。

## 升级步骤（USB 直传 + 原地换目录）

保留旧版可回滚，用「整包落新目录 → 补齐用户文件 → 换名」：

1. 下载对应 zip，PC 解压为 `koreader/` 目录。
2. 把整个目录改名为 `koreader_new`，拷到 `H:\`（逐文件 Copy-Item）。
3. 从旧 `H:\koreader\` 补齐用户文件到 `koreader_new`：
   - `settings/`（含 settings.reader.lua、所有 `*_menu_order.lua`）
   - `cache/`
   - `patches/`（用户 patch）
   - `plugins/` 下所有第三方插件（weread / fanqie / legado / leko 等）
4. 设备上换名（或 PC 上）：
   ```
   Rename koreader → koreader_old_20251105
   Rename koreader_new → koreader
   ```
5. 重启 Kindle → KUAL → KOReader，验证 `版本号` 与 `KindlePaperWhite3` 型号。
6. 确认新版本一切正常后，删 `koreader_old_20251105`（约 125.8 MB）。

## 版本判断

- 新版：`H:\koreader\version.log` 应有 `v2026.07.1, KindlePaperWhite3`。
- 菜单机制源码（升级后核对用）：
  - `frontend/ui/menusorter.lua:22 readMSSettings(config_prefix)` 读 `settings/<prefix>_menu_order.lua`，存在则 dofile 整体覆盖默认 order。
  - `frontend/pluginloader.lua:26` BUILTIN_PLUGINS 列表；`:212-213` 禁用条件 `plugins_disabled[name] or (plugins_disable_external and not BUILTIN_PLUGINS[name])`。
  - `frontend/ui/network/manager.lua:1090 NetworkMgr:getMenuTable()` 注册 network_* 项。

## 升级后必查清单

1. **第三方插件全在**（plugins 目录 + 插件管理里可见）。
2. **menu_order 还在**（settings 下两个 `*_menu_order.lua`），否则菜单恢复默认顺序。
3. **`plugins_disabled` 没被重置**（升级若覆盖 settings.reader.lua 会把 SSH 又禁了，重查一遍，见 02）。
4. **原生微信读书不受影响**（它不依赖 KOReader），但升级后首次启动仍需扫码登录态是否还在。
5. 设备空间：FAT32 1 GB，剩约 444 MB；升级前确保有 130 MB 以上（新旧两包同存）。

## 注意

- 设备 busybox 无 unzip，一切解压在 PC 侧。
- 新版 KOReader 2026.07 新增 `plugins_disable_external` 开关，外部插件不显示先查它。
- 最新稳定版截至实测为 v2026.07.1（2026-11）；v2026.07.2 仅重新生成 nightly 工件，功能相同。

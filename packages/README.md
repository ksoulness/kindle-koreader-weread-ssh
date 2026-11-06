# 安装包归档

项目内自带的安装包，**离线可用**，sha256 已校验。解压后按各文档步骤装进 `H:\koreader\plugins\` 或 USB 根目录。

## 原生微信读书（不依赖 KOReader）

| 文件 | 版本 | 大小 | sha256 |
|---|---|---|---|
| `kindle-weread-0.3.9-install.zip` | 0.3.9 | 47,024,638 B | `16332120e1e10c89b685c42ba01c5e33769afb8a2e56907ee6b8637a25cdaf25` |

- AppID `tech.isword.weread.test`，越狱 + KUAL 即可，无需 KOReader。
- 四目录合并复制到 USB 根：`weread/` + `fonts/` + `documents/` + `extensions/weread/`。
- 详见 [docs/04-微信读书与阅读插件.md](../docs/04-微信读书与阅读插件.md)。

## KOReader 四个插件

| 文件 | 插件 | 版本 | 大小 | sha256 |
|---|---|---|---|---|
| `plugins/weread.koplugin-v1.7.0.zip` | 微信读书 | v1.7.0 | 913,611 B | `5e84d2fdad139d81769cb8bf47868e5ee3b4cfe44602ca6399ad5577171cb5b0` |
| `plugins/legado_plugin_update.zip` | Legado 开源阅读 | 1.2.3 | 522,643 B | `d27b576da5142c6b10598d472f379b26e34e55256f2d2e8e598f5f57547576b7` |
| `plugins/Leko-Reader-KOReader-0.16.0.zip` | Leko 纯本地 | v0.16.0 | 938,337 B | `5b8aa61b8dc99ca05c2db88850537c565cc79a48a66953dd4e739e723ca0cab0` |
| `plugins/fanqie.koplugin.zip` | 番茄小说 | v2.16.36 | 1,059,465 B | `4a9809b825400a89c74b0858bfe88a73d4d8117b341e76d4f2bdfce106f1f79d` |
| `plugins/weread.koplugin-v1.7.0.zip.sha256` | （weread 官方校验文件） | — | 93 B | — |

## 安装与校验

```bash
# PC 侧校验
sha256sum packages/plugins/*.zip packages/kindle-weread-0.3.9-install.zip

# 解压（设备 busybox 无 unzip，必须 PC 解压）
unzip plugins/weread.koplugin-v1.7.0.zip -d weread.koplugin/

# 拷进设备（逐文件 Copy-Item，别 robocopy 递归，见 docs/01）
```

- 四个插件都装到 `H:\koreader\plugins\`，重启 KOReader 后生效。
- 插件入口：工具菜单（weread/fanqie/Legado_main/leko 已统一排序）；Legado 与 Leko 入口特殊，见 [docs/04](../docs/04-微信读书与阅读插件.md)。

## Reeden（独立 Flutter 阅读器）

| 文件 | 大小 | sha256 |
|---|---|---|
| `Reeden-kindle.zip` | 50,928,629 B | `7049657659372db8acfd10619426d24e8a49bfa001666f507c3c43c0c04c5b93` |

- 独立 Flutter 阅读器，非 KOReader 插件，越狱 + KUAL 启动，与 KOReader 互斥。
- 三目录合并复制到 USB 根：`reeden/` + `extensions/reeden/` + `documents/Reeden.sh`。
- 详见 [docs/07-Reeden.md](../docs/07-Reeden.md)。

## Leko 书源订阅模块（源码，非安装包）

| 文件 | 大小 | sha256 |
|---|---|---|
| `plugins/leko-subscription/BookSourceSubscription.lua` | 5,318 B | `309a5899cae379653cae253d2d7f4730e56553b14df431c6eb083bf1ab9a4937` |

- 自造 Leko 书源订阅模块，每天自动拉 `https://jlmon.ccwu.cc/booksource.json`。
- 落位 + App.lua 接线见 [docs/04](../docs/04-微信读书与阅读插件.md)。

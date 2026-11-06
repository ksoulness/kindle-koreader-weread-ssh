# 08 · 垃圾清理与 SSH 装软件

两条日常维护操作：清垃圾腾空间 + 走 SSH 装软件（USB MTP 卡死时的替代通道）。

## 一、垃圾清理

### 四类常见垃圾（本机 2026-11-06 实测全无）

| 目标 | 说明 | 命令 |
|---|---|---|
| `/mnt/us/koreader_old_*` | KOReader 升级旧版本备份，历史最大头（曾到 125.8M） | `rm -rf /mnt/us/koreader_old_*` |
| `/mnt/us/fbcap/` | 帧缓冲 dump（fb.raw 1.5M） | `rm -rf /mnt/us/fbcap` |
| `/mnt/us/weread/runs/<ts>*` | 微信读书残留 run 目录（先 `ps` 确认无 weread 进程） | `rm -rf /mnt/us/weread/runs/*` |
| `/tmp/*.bak*` | 修复过程备份 | 不用管，重启自动清 |

### 大头：cr3cache（CoolReader 渲染缓存）

KOReader 的书籍渲染缓存 `koreader/cache/cr3cache/`（本机 38M），**可再生**——删掉后下次打开书会重新渲染，稍慢但零数据损失。

- **前提：KOReader 必须已退出**。`ps | grep reader.lua` 无输出才安全；运行中删会读写冲突、且退出时可能回写覆盖。
- 顺带清两处死缓存（对应插件已被禁用）：`koreader/cache/calibre/`（calibre 已禁用）+ `koreader/cache/newsdownloader.sqlite`（newsdownloader 已禁用）。

```bash
rm -rf /mnt/us/koreader/cache/cr3cache \
       /mnt/us/koreader/cache/calibre \
       /mnt/us/koreader/cache/newsdownloader.sqlite
```

### 清完核对

```bash
df -h /mnt/us   # 1G 总量；本机清理前 78% / 剩 221.9M，清 cr3cache 后约 260M
```

### 本机实测占比（2026-11-06，796.1M used）

| 目录 | 大小 | 性质 |
|---|---|---|
| `koreader/` | 279M | App + 缓存（cr3cache 38M / legado.cache 6.6M） |
| `reeden/` | 235M | App binary 110M + home 数据 126M（不是垃圾） |
| `books/` | 110M | 用户书 |
| `fonts/` | 53M | 微信读书字体 |

## 二、SSH 装软件（替代 USB MTP）

USB MTP 有两个坑：设备睡眠时盘符不认（`H:` 显示 No Media）、robocopy 递归小文件会卡死。SSH 通道更稳，尤其传大包（实测 Reeden 50.9M 传 ~1MB/s）。

1. PC 端打成 tar.gz（**设备 busybox 无 unzip，必须 tar**）：
   ```bash
   tar czf reeden-install.tar.gz -C <解压目录> reeden extensions documents
   ```
2. pscp 上传：
   ```bash
   pscp -batch -P 2323 -hostkey "SHA256:..." -pw "" reeden-install.tar.gz root@192.168.0.145:/mnt/us/
   ```
3. 设备端解压 + 清理 tarball：
   ```bash
   cd /mnt/us && tar xzf reeden-install.tar.gz && rm reeden-install.tar.gz
   ```
4. 可选校验 ELF 魔数：`dd if=/mnt/us/reeden/reeden/reeden-kindle bs=1 count=4 2>/dev/null | xxd` 应为 `7f 45 4c 46`。

### 连接模板（空密码自动化，PuTTY 版）

```bash
PLINK="/c/Program Files/PuTTY/plink.exe"
HK2323="SHA256:dWzuSpAo89EFX+wPovBs8OuBGE2dHWIMbvkaSvdUnXo"   # 2323 内置 dropbear 主机键
"$PLINK" -batch -ssh -P 2323 -hostkey "$HK2323" -pw "" root@192.168.0.145 '远程命令'
```

- 端口 **2323** = KOReader 内置 dropbear（主用）；**2222** = KOSSH 兜底；root 空密码（`-pw ""`）。
- OpenSSH 交互式连法见 [README](../README.md) 的 SSH 速查段；脚本/自动化用 plink 的 `-pw ""` 最稳。
- ⚠️ **Kindle 睡眠会断 SSH**（`Network error: Connection timed out`），先按电源键唤醒再连。

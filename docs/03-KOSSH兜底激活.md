# 03 · KOSSH 兜底激活内置 SSH

**KOSSH 不是常驻方案，是兜底工具**。只有当「齿轮 → 网络里没有 SSH server」、而你又**不想/不能通过 USB 改文件**时，才装它：用 KOSSH 先拿到一个 shell，再远程把内置 SSH 的插件禁用解除掉，最后让内置 SSH 接管。

## KOSSH 是什么

[guo-yong-zhi/KOSSH](https://github.com/guo-yong-zhi/KOSSH) —— 从 KOReader 剥出来的 dropbear，做成 KUAL 扩展：

- 免密登录（`-n`）、自动开 WiFi、屏幕上刷 IP、防熄屏、**按电源键停服**。
- 端口 2222。
- 自带 dropbear 是旧版 **2018.76**（armhf 32 位，匹配 KPW3 5.12.2），banner `SSH-2.0-dropbear_2018.76`。
- **GitHub releases 没有 release asset**，只能取源码 tar 自己组包。

## 组包结构

```
extensions/KOSSH/
├── dropbear                  # 207,780 B，ELF32 ARM，PT_INTERP=/lib/ld-linux.so.3
├── KOSSH.sh                  # 1,924 B，启动脚本
├── stop_KOSSH.sh             # 325 B，停服脚本
├── PORT                      # 内容 2222
├── config.xml                # 259 B，KUAL 扩展配置
├── menu.json                 # 270 B，KUAL 按钮（Start / Stop）
└── settings/SSH/
    └── dropbear_ecdsa_host_key   # 140 B，dropbear 二进制格式（首字节 00 00 00 13 + "ecdsa-sha2-nistp256"）
```

关键命令（`KOSSH.sh`）：`./dropbear -E -R -p"$PORT" -P KOSSH.pid -n`，结尾 `killall dropbear` + iptables -D；`stop_KOSSH.sh` 同样 `killall dropbear`。

## 部署（USB 直传）

1. 解压源码，把 `dropbear` 二进制 + 上面的脚本/配置/主机密钥按结构放到 `H:\extensions\KOSSH\`（**逐文件 Copy-Item，别 robocopy 递归**）。
2. 安全弹出 H:，在 Kindle 上点 **KUAL → KOSSH → Start**。
3. 屏幕会刷出 IP（`KOSSH.sh:19` 用 `ifconfig wlan0 | grep 'inet addr' | awk -F'[ :]' '{print $13}'` 取，新固件可能取不到值，屏幕 IP 为空不影响用；查路由器拿真实 IP）。

## 用 KOSSH 连进去

和内置 SSH 一模一样的连接模板（root 空密码靠 `-n` 生效）：

```bash
ssh -p 2222 \
  -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
  -o ConnectTimeout=8 \
  -o PreferredAuthentications=password -o PubkeyAuthentication=no \
  -o LogLevel=ERROR \
  root@192.168.0.145
```

banner 应是 `SSH-2.0-dropbear_2018.76`。

## 用它激活内置 SSH（核心动作）

进 shell 后，两步：

```bash
# 1. 解除 SSH 插件禁用（删掉 ["SSH"] = true, 这一行）
sed -i '/\["SSH"\]/d' /mnt/us/koreader/settings.reader.lua

# 2. 确认删干净了
grep -n "SSH" /mnt/us/koreader/settings.reader.lua || echo "CLEAN"
```

然后：

```bash
# 3. 停掉 KOSSH，让内置 SSH 接管 2222（可选：先 kill KOSSH 的 dropbear）
killall dropbear

# 4. 回 Kindle：重启 KOReader（KUAL → KOReader），
#    齿轮 → 网络 → SSH server → 勾 Login without password → 点开关
```

> ⚠️ 改 `settings.reader.lua` 前**必须退出 KOReader**（KUAL 进 KOReader 的话要先退到系统）；KOReader 运行中会把 `plugins_disabled` 缓存进内存、退出时回写覆盖。KOSSH 阶段 KOReader 通常没在跑，安全。

验证内置 SSH 已接管：

```powershell
Test-NetConnection 192.168.0.145 -Port 2222   # True
# banner 应从 2018.76 变为 2026.92 (KOReader)
```

## KOSSH 的坑

1. **端口冲突**：KOSSH 和内置 SSH 都默认 2222，只能活一个。装了 KOSSH 又开内置 SSH → 后启动的 bind 失败。
2. **僵尸进程**：关 KOReader / 停 KOSSH 都不一定杀干净 dropbear，残留进程占端口。判归属看 banner。
3. **屏幕 IP 可能空**：`ifconfig` 输出格式随固件变，取不到值别慌，查路由器。
4. **2018.76 算法老旧**：只支持 rsa/dss/ecdsa 主机密钥，无 ed25519；KEX 提议里没有新版 dropbear 的 `sntrup761`/`kexguess2`。所以**看到 banner 是 2018.76 却想用 ed25519 算法会失败**——连接时别强制 HostKeyAlgorithms=ssh-ed25519，用默认协商即可。

## 结论

KOSSH 用完就停（`stop_KOSSH.sh` / 按电源键 / `killall dropbear`），日常 SSH 用内置的。它唯一的合法存在理由是：**你人在远程、USB 够不着、内置又被禁用时，它是那个「撬门进去解禁」的通道**。

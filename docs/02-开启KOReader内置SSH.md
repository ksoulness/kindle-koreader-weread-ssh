# 02 · 开启 KOReader 内置 SSH

KOReader 自带 SSH 插件（builtin），**正确路径就是用它，不需要另装 KOSSH**。

## 先记结论

「齿轮 → 网络里没有 SSH」的唯一根因 = **SSH 插件被禁用**：

```lua
-- settings.reader.lua
["plugins_disabled"] = {
    ["SSH"] = true,   -- ← 插件不加载 → 菜单项不出现
}
```

`plugins_disabled["SSH"]=true` 时插件根本不加载，`menusorter` 对 item_table 里不存在的 `"ssh"` 项**静默跳过、不报错**。所以菜单里看不到，不是功能缺失。

## 打开方式（在 Kindle 上点）

**前置：如果「齿轮 → 网络」里根本没有「SSH server」这一项**，先解除禁用（见下），再回来点开关。

正常步骤：

1. 进入 KOReader（KUAL → KOReader）。
2. 顶部第 **2** 个标签「**齿轮**」（设置）。
3. 齿轮 → **网络（Network）** → **SSH server**。
4. 子菜单里先勾开关，再点启动：
   - **`Login without password (DANGEROUS)`** → 打开（空密码免密的开关，对应 dropbear `-n`；不勾连上去一直 `Permission denied`）。
   - `SSH port` 保持默认 `2222`。
   - 点 **`SSH server`** 开关（toggle），或点 **`Start SSH server with KOReader`** 直接起。
5. 顶部弹「SSH server started」，此时已监听。

顶部 5 标签顺序：第 1 文件管理设置 / 第 2 齿轮 setting / 第 3 工具 / 第 4 搜索 / 第 5 主菜单。

## 解除插件禁用（唯一必做的首次配置）

两种方式二选一：

**方法 A（界面点，推荐）**：工具（第 3 标签）→ 更多工具（More tools）→ 插件管理（Plugin management）→ 找到 `SSH` → 勾选启用 → 弹重启提示 → 重启 KOReader。

**方法 B（改文件）**：编辑 `settings.reader.lua`，删掉 `plugins_disabled` 表里的 `["SSH"] = true,`，重启 KOReader。

> ⚠️ 方法 B 改文件前必须先**退出 KOReader**：KOReader 运行中把这表缓存在内存，退出时用内存值回写文件，直接改会被覆盖。

## 电脑怎么连

三步走，别一上来就 ssh：

1. **确认 IP**：`192.168.0.145` 是 DHCP 分配，路由器没绑定就会变。查当前 IP：路由管理页 / `ssh nas 'cat /tmp/dhcp.leases'` 搜 `kindle`。
2. **测端口**（Windows PowerShell）：
   ```powershell
   Test-NetConnection 192.168.0.145 -Port 2222   # TcpTestSucceeded : True 才继续
   ```
3. **连接**（Git Bash 或 `C:\Windows\System32\OpenSSH\ssh.exe`）：
   ```bash
   ssh -p 2222 \
     -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
     -o ConnectTimeout=8 \
     -o PreferredAuthentications=password -o PubkeyAuthentication=no \
     -o LogLevel=ERROR \
     root@192.168.0.145
   ```

- 进 shell 后 `id` 应回 `uid=0(root) gid=0(root)`。
- **免密的关键**：root 是空密码，**必须带 `PreferredAuthentications=password` + `PubkeyAuthentication=no`**。裸 `ssh -p 2222 root@...` 走 BatchMode 会报 `Permission denied (publickey,password)`，这是空密码账号的正常表现，不是配置错。

## IPv4 问题（实测纠正）

之前记录「内核无 IPv6 必须 patch `main.lua` 绑 `0.0.0.0`」是**错误结论**。实测 dropbear 2026.92 在这台无 IPv6 的 KPW3 上：

| 命令 | 结果 |
|---|---|
| `./dropbear -E -R -p 9998`（纯端口） | 监听 `0.0.0.0:9998` ✅ |
| `./dropbear -E -R -l wlan0 -p 9997`（绑接口） | 监听 `0.0.0.0:9997` ✅ |
| `./dropbear -E -R -p 192.168.0.145:9996`（绑具体 IP） | 监听该 IP ✅ |

**保持 `main.lua` 原始 `"-p", self.SSH_port` 不动即可**，`SSH_port` 写纯端口号（如 `"2222"`）。真正的坑是：**别把端口写成 `0.0.0.0:2222` 格式**——它会让 `iptables --dport` 打洞失败（`--dport` 只认纯端口），导致 INPUT DROP 兜底、外部连超时。

`SSH:start()` 原始命令：`./dropbear -E -R -p 2222 -P /tmp/dropbear_koreader.pid`，`Device:isKindle()` 时打 iptables 洞（`iptables -A INPUT -p tcp --dport 2222` + OUTPUT `--sport 2222`）。

## 排障顺序（连不上按这个查，别跳）

1. 端口没开 → 确认服务真启动了（`Test-NetConnection` 假）。
2. banner 应为 `SSH-2.0-dropbear_2026.92 (KOReader)`。若不是 = 有僵尸进程占了端口（见踩坑）。
3. 握手在 `KEX_ECDH_REPLY` 阶段断 = 服务器缺主机私钥（`settings/SSH/` 空）。
4. 反复 `Permission denied` = 没开 `Login without password`，或漏了那两个 ssh 选项。

## 踩坑：内置 dropbear 是僵尸进程

关掉 KOReader 不杀它的 dropbear daemon，残留进程占端口。表现：重启服务但端口还是旧 banner。处理：重启 Kindle，或 `killall dropbear` 后再启。

判端口归属看 banner：`SSH-2.0-dropbear_2026.92 (KOReader)` = 内置；`SSH-2.0-dropbear_2018.76` = KOSSH。

## 内置 SSH 相关源码位置

- `plugins/SSH.koplugin/main.lua` — builtin 插件，`pluginloader.lua:26` 列表含 `["SSH"]=true`。
- `main.lua:19-21` 守卫：`if not util.pathExists("dropbear") then return { disabled = true } end`（相对路径依赖 cwd=`/mnt/us/koreader`）。
- `main.lua:30` `self.SSH_port = G_reader_settings:readSetting("SSH_port") or "2222"`。
- `main.lua:44-85 SSH:start()` — 启动命令 + iptables 打洞。
- `main.lua:246 addToMainMenu(menu_items)` — 注册 `menu_items.ssh`（无 sorting_hint，靠 order 文件归位到 network 组）。

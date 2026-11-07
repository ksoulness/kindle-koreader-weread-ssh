# Reader3 用户与三种客户端同步

Reader3 部署好后，需要：① 开通账号；② 让 Kindle / 手机 / 网页三个客户端连上。

> 实测时间 **2026-11-07**。当前唯一账号 `jl413`（注册已锁定）。

## 1. 新增用户（注册已锁定时）

`READER_APP_USERLIMIT=1` 时新注册会被拦。开通新用户流程：

```bash
ssh nas
cd /vol1/1000/docker/apps/reader

# 1) 备份 compose
cp docker-compose.yml docker-compose.before-add-user-$(date +%Y%m%d).yml

# 2) 临时放开注册上限（如 2）
sed -i 's/READER_APP_USERLIMIT=1/READER_APP_USERLIMIT=2/' docker-compose.yml
docker compose up -d --no-deps reader

# 3) 注册新用户
curl -X POST 'http://192.168.0.117:4396/reader3/login' \
  -H 'Content-Type: application/json' \
  -d '{"username":"新用户名","password":"密码","code":"","isLogin":false,"v":1}'
# 返回 isSuccess:true 即成功

# 4) 改回锁定
sed -i 's/READER_APP_USERLIMIT=2/READER_APP_USERLIMIT=1/' docker-compose.yml
docker compose up -d --no-deps reader
```

> 关键：注册接口 `isLogin:false` 才是注册，`isLogin:true` 是登录。改完记得把 USERLIMIT 改回 1。

## 2. Kindle 同步（KOReader + Legado 插件）

Kindle 用 KOReader 的 **Legado 插件**连 Reader3。

插件：`pengcw/legado.koplugin`（真机 v1.2.3）。配置在 `/mnt/us/koreader/settings/legado.lua`：

```lua
server_address = "https://reader3.jlmon.ccwu.cc/reader3"  -- 注意带 /reader3 路径
server_type = 2                                           -- 2 = reader3 协议
reader3_un = "jl413"
reader3_pwd = "jingli413"
current_conf_name = "reader3"
```

插件架构（改补丁必读）：
```
Legado/Backend.lua                    通用层（loadApiProvider 按 server_type 加载）
Legado/spore/reader3.lua              reader3 实现（getBookshelf/getChapterList/getBookContent...）
Legado/spore/reader3_spec.lua         接口 spec
Legado/spore/base.lua                 基类（handleResponse/tokenManager/ensureLogin）
```

> **鉴权方式**：token 拼 **URL query string**（`?accessToken=xxx`），不是 header。登录接口在 `reader3.lua` 里 POST `/login`，token 存本地，过期自动重登。

## 3. 手机同步（「阅读」App）

手机装「阅读」App（`io.legado.lc.app.release`），两种方式：

### 方式 A：直接连 Reader3（推荐）

App 内「我的 → 服务器设置」填 Reader3：
- 服务器地址：`https://reader3.jlmon.ccwu.cc/reader3`
- 账号：`jl413` / `jingli413`

> 版本坑：LucyyHH/legado 的 **master 新版用 `/api/v1`**（`ReaderServerV1.kt`），与 Reader3 的 `/reader3` 不兼容。要用 **3.26.05082017 旧版 APK**（`ReaderServerApi.kt` 里 `API_PREFIX="/reader3"`），或选 App 里「阅读 3.0 / reader3」服务器类型。

### 方式 B：WebDAV（备份/同步书文件）

- 地址：`https://reader3.jlmon.ccwu.cc/reader3/webdav/`
- 账号：`jl413` / `jingli413`
- 开启鉴权后匿名 WebDAV 返回 401，必须带账号。

## 4. 网页同步

直接浏览器打开 `https://reader3.jlmon.ccwu.cc`，登录 `jl413`。

网页版（前端 `reader.js` + `app.js`）能力：
- 书架/搜索/阅读/换源/导出/删除
- **「书源」按钮**：读某本书时点它，调 `/getAvailableBookSource` 列出该书其他源，点选即换源（`/setBookSource`）。这是网页能打开死源书、而 Kindle 插件打不开的原因——网页有手动换源 UI，插件没有（直到打了自动换源补丁）。

## 5. 三种客户端对比

| | 打开书 | 换源 | 加书 | 备注 |
|---|---|---|---|---|
| Kindle | Legado 插件 | 自动（补丁后） | 网页加 | 离线读已缓存章节 |
| 手机 | 阅读 App | 手动 | 搜索加书 | 书源是手机本地库，与 Reader3 不同步 |
| 网页 | 浏览器 | 手动按钮 | 搜索加书 | 功能最全，书源在服务端 |

## 6. 关键认知：书源不随书单同步

**这是踩坑最多的点**：手机「阅读」App 的书源和 Reader3 的书源是**两套独立书源库**。

- 手机 App 里用「小众书源」加的书，同步到 Reader3 时**只同步书单 + 每本书绑定的 origin URL，不同步书源抓取规则**。
- 结果：Reader3 服务端书源库里没有这些小众源 → Kindle / 手机 App 连 Reader3 打开这些书都报「未找到书源」/「目录为空」。
- 解决：见 [11-Legado自动换源补丁](11-Legado自动换源补丁.md) 和 [12-踩坑清单](12-踩坑清单.md)。

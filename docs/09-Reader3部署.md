# Reader3 部署（NAS 飞牛 fnOS）

Reader3 = 自建「阅读 3.0」书库服务（镜像 `changshengyu/reader:latest`）。Kindle / 手机 / 网页三个客户端都连它，书源和书架在服务端统一管理。

> 实测时间 **2026-11-07**。NAS = 飞牛 fnOS，内网 `192.168.0.117`。

## 架构总览

```
公网客户端 ──▶ Cloudflare 隧道 ──▶ NAS
                                 ├─ reader3.ksoul.top      → 4396 → reader 容器(8080)  ← 主入口
                                 ├─ reader3.jlmon.ccwu.cc → 4396 → reader 容器(8080)  ← 备用入口
                                 └─ jlmon.ccwu.cc         → 4397 → nginx booksource(80) ← 书源
```

- **reader 容器**：书库主服务（书架/书源/章节/正文全在这）。
- **booksource 容器**：nginx，托管书源 JSON 合集（供 reader 订阅书源用）。
- **Cloudflare 隧道**：把三个域名打到 NAS 两个端口，无需公网 IP / 端口映射。

## 1. docker-compose

路径：`/vol1/1000/docker/apps/reader/docker-compose.yml`

```yaml
services:
  reader:
    image: changshengyu/reader:latest
    container_name: reader
    restart: unless-stopped
    ports:
      - "4396:8080"
    volumes:
      - /vol1/1000/docker/apps/reader/logs:/logs
      - /vol1/1000/docker/apps/reader/storage:/storage
    environment:
      - READER_APP_SECURE=true        # 登录鉴权（false=匿名可读写）
      - READER_APP_USERLIMIT=1        # 注册数上限（1=锁定，不开放注册）
      - READER_APP_USERBOOKLIMIT=500  # 单用户书架上限
  booksource:
    image: nginx:latest
    container_name: booksource
    restart: unless-stopped
    ports:
      - "4397:80"
    volumes:
      - /vol1/1000/docker/apps/reader/web:/usr/share/nginx/html:ro
```

- 服务端 jar：`/app/bin/reader.jar`（38MB）。
- 数据目录：`/vol1/1000/docker/apps/reader/storage/data/{账号}/`
  - `bookshelf.json` 书架、`bookSource.json` 书源、`bookGroup.json` 分组、`rssSources.json`
  - `webdav/` 每本书一个目录（书名_作者）。

### 环境变量语义（重要）

| 变量 | 含义 | 实测值 |
|---|---|---|
| `READER_APP_SECURE` | `true` 后所有接口需登录 token；匿名 `getBookshelf`/`deleteBook` 返回 `NEED_LOGIN`，WebDAV 401 | true |
| `READER_APP_USERLIMIT` | 允许注册的用户数上限。**=1 时新注册被拦**（`isSuccess:false`） | 1 |
| `READER_APP_USERBOOKLIMIT` | 单用户书架书数上限 | 500 |

改配置后 `docker compose up -d --no-deps reader` 重建生效。改前先备份 compose 文件。

## 2. 书源服务

- 书源 JSON 合集放在 `booksource` 容器的 web 目录：`/vol1/1000/docker/apps/reader/web/`。
- Reader3 有**书源健康同步机制**：`/logs/sync.log` 记录 `subscription=451 reader=451 healthy=380 failed=41 skipped=30 deleted=0`，会**自动删除不健康书源**（实测 451 → 352，删了 97 个）。
- 被删书源有快照备份：`/vol1/1000/docker/apps/reader/logs/booksource-before-delete-*.json`。

## 3. Cloudflare 公网（隧道 + DNS）

| 项 | 值 |
|---|---|
| 隧道 ID | `c43cf4ca-6059-479c-b473-0d6470b3fa9f` |
| 账号 ID | `14fd538ad13cb22f60e2d6989ecb4bc8` |
| zone | `jlmon.ccwu.cc`（id `b5fa39d0d0fe002f66729ff56619419d`） |

| 域名 | 指向 | 用途 |
|---|---|---|
| `reader3.ksoul.top` | NAS 4396 | 原主入口 |
| `reader3.jlmon.ccwu.cc` | NAS 4396 | 备用入口（2026-11-07 新增，CNAME 到隧道） |
| `jlmon.ccwu.cc` | NAS 4397 | 书源合集（根路径 403 正常，需具体文件路径） |

改隧道配置前备份：`F:\User\Temp\reader3-tunnel-before-v68.json`（v68 → v69）。

## 4. 数据迁移（default → 具名账号）

开启鉴权前，数据都在 `default` 账号。迁移到具名账号（如 `jl413`）：

```bash
ssh nas
cd /vol1/1000/docker/apps/reader/storage/data
cp -a default jl413
```

- 复制过程中若新书入库，用 `bookshelf.json` 合并补齐（备份 `bookshelf.before-merge.bak`）。
- 迁移后验证：登录 `jl413` 后 `getBookshelf` 书数 = 迁移前 default 书数。

## 5. 鉴权接口速查

| 接口 | 方法 | 说明 |
|---|---|---|
| `/reader3/login` | POST `{username,password,code:"",isLogin,v}` | `isLogin:true` 登录拿 `data.accessToken`；`isLogin:false` 注册 |
| `/reader3/getBookshelf` | GET `?accessToken=` | 书架列表（token 拼 query，**不是 header**） |
| `/reader3/getChapterList` | GET `?url=&accessToken=` | 目录（`url` 是 **bookUrl** 不是 origin） |
| `/reader3/getBookContent` | GET `?url=&index=&accessToken=` | 正文 |
| `/reader3/getBookSources` | GET `?simple=1&accessToken=` | 书源列表 |
| `/reader3/setBookSource` | POST `{bookUrl,bookSourceUrl,newUrl,v}` | 换源（**token 拼 URL query**，body 不带） |
| `/reader3/getAvailableBookSource` | POST `{url,refresh}` | 查某书可用源（死源书会返回「书籍信息错误」） |
| `/reader3/searchBookMultiSSE` | GET `?key=&searchSize=50&...&accessToken=` | 按书名多源搜索（SSE 流） |
| `/reader3/deleteBooks` | POST `[书对象数组]` | 删书 |
| `/reader3/saveBook` | POST 书对象 | 加书 |

> **token 每次登录都会变**，脚本里要每次重新登录拿 token，不要硬编码。

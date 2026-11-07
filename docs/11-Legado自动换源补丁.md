# Legado 自动换源补丁

解决 Kindle KOReader Legado 插件打开书报「chapter list is empty」和「目录为空 TocEmptyException」的根因：**本地书架记的源地址已死，插件不会自动换源**。

> 实测时间 **2026-11-07**。只改一个文件：`Legado/spore/reader3.lua`。

## 1. 问题现象

- 打开书 → 目录页显示 `Chapter list is empty. Try swiping down to refresh.`
- 下载章节 → `下载章节失败 io.legado.app.exception.TocEmptyException:目录为空`
- 同一本书在**网页版能正常看**（网页有手动「书源」换源按钮，Kindle 插件没有）。

## 2. 根因

书源不随书单同步（见 [10-Reader3用户与同步](10-Reader3用户与同步.md) 第 6 节）。书架里存的是 `origin`（书源 URL），Reader3 服务端书源库没有这些小众源 → `getChapterList`/`getBookContent` 返回「未找到书源」。

更隐蔽的坑：**目录换源成功 ≠ 正文能下载**。下载章节链路里 `chapter.bookUrl` 从本地 books 表读（还是死源），换源改的是目录流程里的独立对象，没写回 books 表 → 下载正文仍用死源 → `TocEmptyException`。

下载链路（读代码确认）：
```
ReadingFlow.lua:249   reading_chapter.bookUrl = bookinfo.bookUrl  (死源)
Backend.lua:2466      downloadChapter(reading_chapter)
Backend.lua:1413      _pDownloadChapter: local bookUrl = chapter.bookUrl
Backend.lua:897       pGetChapterContent → apiClient:getBookContent(chapter)
reader3.lua:239       getBookContent: 用 chapter.bookUrl
```

## 3. 补丁原理（三层兜底）

只改 `reader3.lua`，给 `getChapterList` 和 `getBookContent` 都加「失败自动换源重试」：

```
请求(url) 失败 且 err 是死源错误
  ├─ 第一层 _findServerBookUrl：pcall(getBookshelf) 同步拿服务端书架，
  │    按「书名+作者」精确匹配（其次仅书名）找服务端活源 bookUrl
  │    → 找到不同 bookUrl 就写回 bookinfo，用活源重试
  └─ 第二层 _autoChangeBookSourceSync：searchBookMultiSSE?key=书名（SSE 流）
       收集候选 → 作者精确匹配优先 → setBookSource 换源 → 用新源重试
```

- 第一层覆盖「服务端书架已经是活源、只是本地 DB 过时」的场景（批量换源后最常见）。
- 第二层覆盖「服务端也死源」的场景（需要搜索活源换源）。
- 换源成功后把活源的 `bookUrl/origin/originName` 写回 `bookinfo` 引用（或 `chapter` 引用），这样 Backend 层后续 upsert 到本地 DB。

## 4. 关键代码改动（reader3.lua）

| 改动 | 位置 | 说明 |
|---|---|---|
| `_isSourceDeadError(err)` | L178 附近 | 匹配 `未找到书源`/`未配置书源`/`本地书籍源文件不存在`/`TocEmptyException`/`目录为空` |
| `_findServerBookUrl(bookinfo)` | L185 附近 | 同步 getBookshelf 按书名+作者匹配活源 |
| `_applyAutoSource(bookinfo, src)` | 新增 | 把活源 bookUrl/origin/originName 写进 bookinfo 引用 |
| `_autoChangeBookSourceSync(bookinfo)` | L504 附近 | 按书名搜索换源（SSE 同步拉，支持 RETRY_LOGIN） |
| `getChapterList` | L143 附近 | 拆 `fetch(url)` 闭包，失败+死源 → 两层兜底 → 重试 |
| `getBookContent` | L239 附近 | 同上，构造 `pseudo={bookUrl,name,author}` 走两层兜底 |

> 注意 Lua 作用域：`fetch_sse_stream_sync` 是 reader3.lua **L367-477 的顶层 local function**，`_autoChangeBookSourceSync` 必须定义在它**之后**才能引用它。

## 5. 部署方法

```bash
# 1) 备份原文件
ssh -p 2323 root@192.168.0.145
cd /mnt/us/koreader/plugins/legado.koplugin
cp Legado/spore/reader3.lua .legado_autosource_backup/reader3.lua.vN.bak

# 2) 覆盖补丁版（本机 legado-device/Legado__spore__reader3.lua）
# scp -P 2323 legado-device/Legado__spore__reader3.lua root@192.168.0.145:/mnt/us/koreader/plugins/legado.koplugin/Legado/spore/reader3.lua

# 3) 语法校验（KOReader 的 luajit 剥了 jit 模块，-bl 不可用）
luajit -e "local fn,err=loadfile('Legado/spore/reader3.lua'); print(fn and 'SYNTAX OK' or err)"

# 4) 重启 KOReader
kill -9 <主进程pid>
nohup /mnt/us/koreader/koreader.sh --kual >/dev/null 2>&1 &

# 5) 确认加载无 error
tail -30 /mnt/us/koreader/crash.log
```

备份目录 `/mnt/us/koreader/plugins/legado.koplugin/.legado_autosource_backup/`：
- `reader3.lua.bak` 原始 27977 字节
- `v1patch.bak` 32894（仅 getChapterList 换源）
- `v2patch.bak` 33568（三层）
- `v3patch.bak` 35655（加 _applyAutoSource + Backend.lua 联动）
- `v4patch.bak` 最终版（加 getBookContent 换源 + TocEmptyException 识别），37744 字节

## 6. 补丁文件

见 [packages/plugins/legado-autosource/](../packages/plugins/legado-autosource/README.md)：`patched/` 补丁版 + `original/` 原始版。

## 7. 验证结果

- 实测《都重生了谁考公务员啊》：本地死源 `elkparts` → 补丁自动换到活源 `xyuzhaiwu10` → 目录 747 章、正文正常。
- Kindle 本地 242 本书中 77 本本地 bookUrl 是死源，打开时都会自动换源。
- 7 本「源彻底死」的书（服务端书源库也没有活源）无法换源，属数据层面缺失，需手动删。

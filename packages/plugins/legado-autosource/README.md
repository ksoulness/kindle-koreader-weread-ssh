# Legado 自动换源补丁（reader3）

给 Kindle KOReader 的 **Legado 插件**（`pengcw/legado.koplugin`）的 reader3 实现加「打开失败自动换源」，解决书架里死源书打不开的问题。

## 解决什么

- 打开书 → `Chapter list is empty. Try swiping down to refresh.`
- 下载章节 → `io.legado.app.exception.TocEmptyException:目录为空`
- 同一本书网页版能看（网页有手动「书源」换源按钮，Kindle 插件没有）。

根因：书源不随书单同步，书架绑定的 `origin`（书源 URL）在 Reader3 服务端书源库里不存在（死源），插件不会自动换源。

## 文件结构

```
legado-autosource/
├── original/Legado/spore/reader3.lua   原始真机版（27977 字节，v1.2.3）
├── patched/Legado/spore/reader3.lua    补丁版（37744 字节）
└── README.md
```

补丁**只改 `reader3.lua` 一个文件**，其他文件不动。

## 补丁内容（三层兜底）

给 `getChapterList` 和 `getBookContent` 都加「失败自动换源重试」：

1. **识别死源错误**：`未找到书源` / `未配置书源` / `本地书籍源文件不存在` / `TocEmptyException` / `目录为空`。
2. **第一层（书架同步活源）**：`getBookshelf` 同步拿服务端书架，按「书名+作者」匹配活源 bookUrl，写回 bookinfo 后重试。
3. **第二层（搜索换源）**：`searchBookMultiSSE?key=书名` 按书名搜候选源，作者精确匹配，`setBookSource` 换源后重试。

换源成功后把活源 `bookUrl/origin/originName` 写回 `bookinfo`（引用传递），Backend 层会 upsert 到本地 DB。

## 安装

```bash
# 1) 备份原文件
cd /mnt/us/koreader/plugins/legado.koplugin
cp Legado/spore/reader3.lua .legado_autosource_backup/reader3.lua.bak

# 2) 覆盖补丁版（本机把 patched/Legado/spore/reader3.lua 传上去）
# scp -P 2323 patched/Legado/spore/reader3.lua \
#   root@192.168.0.145:/mnt/us/koreader/plugins/legado.koplugin/Legado/spore/reader3.lua

# 3) 语法校验
luajit -e "local fn,err=loadfile('Legado/spore/reader3.lua'); print(fn and 'SYNTAX OK' or err)"

# 4) 重启 KOReader
kill -9 <主进程pid>
nohup /mnt/us/koreader/koreader.sh --kual >/dev/null 2>&1 &
```

## 回滚

```bash
cd /mnt/us/koreader/plugins/legado.koplugin
cp .legado_autosource_backup/reader3.lua.bak Legado/spore/reader3.lua
# 重启 KOReader
```

## 适用版本

- KOReader v2026.07.1（Kindle Paperwhite 3）
- legado.koplugin v1.2.3（真机，reader3.lua 836 行）

> 上游 master（github pengcw/legado.koplugin）的 reader3.lua 只有 474 行，与真机 v1.2.3 差异大。**补丁基于真机 v1.2.3 制作**，不要直接套到上游 master。

## 验证

- 实测《都重生了谁考公务员啊》：死源 `elkparts` → 自动换到活源 `xyuzhaiwu10` → 目录 747 章、正文正常。
- 书架 242 本中 77 本本地 bookUrl 是死源，打开时自动换源。
- 7 本「源彻底死」的书（服务端书源库无活源）无法换源，属数据缺失，需手动删。

## 详细原理与踩坑

见仓库根目录文档：
- [11-Legado自动换源补丁](../../../../docs/11-Legado自动换源补丁.md)
- [12-踩坑清单](../../../../docs/12-踩坑清单.md)
- [09-Reader3部署](../../../../docs/09-Reader3部署.md)

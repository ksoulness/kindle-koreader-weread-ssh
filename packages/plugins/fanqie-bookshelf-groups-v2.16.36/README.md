# 番茄小说书架分组补丁

适用版本：hesan1232 fanqie.koplugin v2.16.36，KOReader Kindle 版。此备份包含修改后的四个插件文件和修改前的对应原件，不包含登录设置、Cookie 或书架缓存。

官方书架接口返回分组信息；原插件未将其保留并用于书架筛选。补丁保留分组字段，并在书架操作菜单加入「分组」筛选，支持按分组查看书籍。书架数据需联网刷新后才会带上分组信息。

## 安装

1. 退出 KOReader，备份现有 `koreader/plugins/fanqie.koplugin/`。
2. 将 `patched/` 内的文件按原有目录结构复制到 `koreader/plugins/fanqie.koplugin/`，覆盖同名文件。
3. 启动 KOReader，进入番茄书架，使用书架操作菜单刷新书架，再选择「分组」。

原有书架缓存若没有分组数据，刷新后才会显示分组；必要时可先备份并移走 `koreader/fanqie/cache/shelf_cache.lua`，再联网进入书架。缓存目录随插件下载目录设置而变化。

## 回滚

退出 KOReader，将 `original/` 内四个文件按同样的目录结构覆盖回插件目录，再启动 KOReader。这些原文件来自打补丁前的 v2.16.36；其他版本应使用其安装前自行保存的备份。

## 验证记录

四个修改文件通过 Kindle 上 KOReader 自带 LuaJIT 的 `loadfile` 语法检查；KOReader 重启后插件初始化未见报错。分组界面的实际交互未在本次设备操作中独立验证。

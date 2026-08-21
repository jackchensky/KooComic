# koo漫画 for KOReader v0.4.0

在 KOReader 中登录自己的 KOOBONE 账号、浏览个人漫画书库、下载完整 EPUB 并直接阅读。

> koo漫画是独立开发的非官方 KOReader 插件，与 KOOBONE、Bookof.hk 及其开发者不存在隶属、赞助或官方合作关系。KOOBONE 名称仅用于说明兼容服务。

## 主要功能

- 自动迁移旧版 `koobone.lua` 中的登录会话和设置，不删除旧文件。
- 优先验证现有 Cookie，失效后再提示登录。
- 可选“记住密码”，默认关闭，并明确提示密码保存在本机设置中。
- 账号状态、清除密码和退出账号。
- 自适应封面网格；可分别设置竖屏/横屏的封面列数和行数，并可调整界面文字大小。
- 搜索、最近加入/标题/阅读进度排序，以及下载和阅读状态筛选。
- 封面、阅读进度与下载状态角标、首尾页/上一页/下一页导航。
- 底部书架、下载、账号、设置导航；不支持自定义网格的旧版 KOReader 自动回退到列表。
- HTTPS 封面按稳定书籍标识缓存在 KOReader 数据目录，失败时显示墨水屏占位封面。
- 书籍详情与下载状态。
- 流式写入 `.part`，显示下载百分比、大小、速度和预计剩余时间。
- 下载网络层遵循 KOReader 的统一 LuaSocket HTTPS 兼容路径，并保留底层超时或连接错误原因。
- 下载失败或取消后保留临时文件，避免产生伪装成完整 EPUB 的损坏文件。
- 下载记录页面。
- 版本检查、每天最多一次提醒、三次“稍后更新”后停止自动提醒。
- 更新包大小与 SHA-256 校验、安全解压、旧版本备份和失败回滚。

## 安装

删除旧的插件代码目录（不要删除设置和漫画），再将整个 `koocomic.koplugin` 文件夹复制到：

```text
koreader/plugins/
```

完全重启 KOReader，然后打开：

```text
工具 → koo漫画
```

## 在线更新

插件通过公开 GitHub Release 下载更新，并从 GitHub Pages 读取固定版本清单。当前地址配置在 `koobone/plugin_version.lua`：

```lua
manifest_url = "https://jackchensky.github.io/KooComic/update.json"
release_prefix = "https://github.com/jackchensky/KooComic/releases/download/"
```

自动检查只读取版本清单；下载和安装新版本前仍会要求用户确认，并校验文件大小和 SHA-256。

## 安全说明

- 插件不会要求手动粘贴 `KBSKEY` 或 `VLIBSID`。
- 不要分享 KOOBONE Cookie、密码、完整签名下载地址或调试日志中的敏感信息。
- 只有主动勾选“记住密码”才会在 Kindle 本机设置文件中保存密码。
- 退出账号会清除会话和保存的密码，不删除已下载漫画。
- 封面缓存只包含公开书籍封面，不保存账号 Cookie 或签名下载地址。
- KOOBONE 并未提供公开 API，网页端接口变化可能导致插件失效。

## 许可证

本项目采用 GNU Affero General Public License v3.0 only（`AGPL-3.0-only`）。详情见随插件提供的 `LICENSE` 和 `NOTICE`。

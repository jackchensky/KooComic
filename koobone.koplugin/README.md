# KOOBONE for KOReader v0.2

在 KOReader 中登录自己的 KOOBONE 账号、浏览个人漫画书库、下载完整 EPUB 并直接阅读。

## v0.2 功能

- 自动迁移 v0.1 已保存的登录会话。
- 优先验证现有 Cookie，失效后再提示登录。
- 可选“记住密码”，默认关闭，并明确提示密码保存在本机设置中。
- 账号状态、清除密码和退出账号。
- 墨水屏友好的分页书架、书籍详情与下载状态。
- 流式写入 `.part`，显示下载百分比、大小、速度和预计剩余时间。
- 下载失败或取消后保留临时文件，避免产生伪装成完整 EPUB 的损坏文件。
- 下载记录页面。
- 版本检查、每天最多一次提醒、三次“稍后更新”后停止自动提醒。
- 更新包大小与 SHA-256 校验、安全解压、旧版本备份和失败回滚。

## 安装

将整个 `koobone.koplugin` 文件夹复制到：

```text
koreader/plugins/
```

完全重启 KOReader，然后打开：

```text
工具 → KOOBONE
```

## 在线更新

代码已经包含安全更新框架，但在 GitHub 仓库和 Release 地址确定之前默认关闭。发布仓库创建后，需要在 `koobone/plugin_version.lua` 中配置：

```lua
manifest_url = "https://.../update.json"
release_prefix = "https://github.com/.../releases/download/"
```

不得使用占位地址发布插件。

## 安全说明

- 插件不会要求手动粘贴 `KBSKEY` 或 `VLIBSID`。
- 不要分享 KOOBONE Cookie、密码、完整签名下载地址或调试日志中的敏感信息。
- 只有主动勾选“记住密码”才会在 Kindle 本机设置文件中保存密码。
- 退出账号会清除会话和保存的密码，不删除已下载漫画。
- KOOBONE 并未提供公开 API，网页端接口变化可能导致插件失效。

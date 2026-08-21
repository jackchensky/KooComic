# koo漫画

一个连接用户个人 KOOBONE 漫画书库的非官方 KOReader 插件，可在 Kindle/KOReader 上浏览封面书架、下载 EPUB 并阅读。

> 本项目与 KOOBONE、Bookof.hk 及其开发者不存在隶属、赞助或官方合作关系。KOOBONE 名称仅用于说明兼容服务。

## 安装

从 Releases 下载最新版，将压缩包内的 `koocomic.koplugin` 复制到 `koreader/plugins/`，然后完全重启 KOReader。

从 v0.3.1 或更早版本升级时，只删除旧的 `plugins/koobone.koplugin` 代码目录；请保留 `settings/koobone.lua` 和原有漫画下载目录，以便迁移登录状态和本地文件。

## 通过 Storefront 安装

本仓库已添加 Storefront 识别所需的 `koreader-plugin` GitHub Topic，并已进入 Storefront 的默认静态目录。在 Storefront 中使用默认的“Storefront”目录来源并刷新插件目录后，可搜索 `KooComic`、`KOOBONE` 或“漫画”找到本插件。

不建议为了搜索本插件切换到“Direct GitHub API”：GitHub 完整 Topic 搜索会分页，未认证请求还可能被限速，导致零星新仓库没有进入设备缓存。无论使用 Storefront 还是手动安装，插件设置和已下载漫画都保存在插件代码目录之外，更新插件时请勿删除这些数据。

详细功能、隐私和在线更新说明见 [`koocomic.koplugin/README.md`](koocomic.koplugin/README.md)。开发状态见 [`PROJECT_STATUS.md`](PROJECT_STATUS.md)。

## 许可证

本项目采用 [GNU Affero General Public License v3.0 only](LICENSE)，SPDX 标识为 `AGPL-3.0-only`。

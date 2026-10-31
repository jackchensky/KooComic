<p align="center">
  <img src="assets/koocomic-social-preview.jpg" alt="KooComic·可漫 — KOReader 漫画书架" width="100%">
</p>

# KooComic·可漫

[![CI](https://github.com/jackchensky/KooComic/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/jackchensky/KooComic/actions/workflows/ci.yml)
[![Latest release](https://img.shields.io/github/v/release/jackchensky/KooComic?label=release)](https://github.com/jackchensky/KooComic/releases/latest)
[![GitHub stars](https://img.shields.io/github/stars/jackchensky/KooComic?style=flat&label=stars)](https://github.com/jackchensky/KooComic/stargazers)
[![License: AGPL-3.0-only](https://img.shields.io/badge/license-AGPL--3.0--only-blue.svg)](LICENSE)

KooComic·可漫由 Jackchen 独立开发和维护，依照 KOOBONE 提供的 API Key 接口方案连接用户个人漫画书库，让你可以在 Kindle/KOReader 上浏览封面书架、下载 EPUB 并直接阅读。

> 用Koo可漫让你的KOOBONE漫画在Kindle上可以自在漫读。—— @Jackchen

本插件不是 KOOBONE 官方客户端。插件的界面、功能、发布与后续维护由本项目独立负责；KOOBONE 名称用于说明所连接的服务与接口来源。

> ⭐ 如果 Koo可漫对你有帮助，欢迎为项目点亮一个 **Star**。你的支持能帮助更多 KOReader 用户发现它，也能让我们知道这个插件值得继续维护。想及时收到新版通知，可以选择 GitHub 的 **Watch → Custom → Releases**，或在插件内使用版本检查。

## 功能亮点

- 墨水屏友好的封面书架，自适应横竖屏并可调整行列数和文字大小。
- 搜索、排序和下载/阅读状态筛选，支持书籍详情与分页浏览。
- 流式下载 EPUB，显示百分比、大小、速度和预计剩余时间。
- 通过 KOOBONE API Key 连接个人书库；密钥保存在 Kindle 本机，连接成功后无需重复输入，可随时更换密钥或退出账号。
- 封面本地缓存、下载管理和旧版 KOReader 的列表界面回退；可删除本地漫画、清理失效记录及未完成临时文件。
- 通过 GitHub Release 在线更新，安装前校验文件大小和 SHA-256，失败时尝试回滚。
- 新安装默认每天检查一次新版本；每天最多提醒一次，连续三次选择“稍后更新”后停止自动弹窗，仍可手动检查。下载和安装始终需要用户确认。

当前公开版本为 **v0.4.2**。插件已在 Kindle/KOReader 真机上持续迭代，但设备型号、KOReader 版本和 KOOBONE 接口都可能影响兼容性，欢迎提交脱敏后的测试反馈。

## v0.4.2 大版本更新

v0.4.2 不只是登录修复，而是从认证、书架到本地文件管理的一次整体升级：

- **API Key 登录**：采用 KOOBONE 提供的 API Key 接口方案，不再向插件输入账号密码；连接成功后无需每次重复输入。旧版设置和下载记录会继续保留，账号页可更换 Key、清除旧密码或退出账号。
- **全新墨水屏书架**：加入继续阅读区、四列三层封面书架、统一线框图标和底部导航。布局会根据屏幕尺寸、横竖屏、行列数及文字大小重新计算，而不是只针对某一款 Kindle 写死坐标。
- **黑白和彩色共用一套插件**：黑白 Kindle 自动呈现高对比灰阶界面，彩色墨水屏显示暖纸色、棕色文字和彩色封面。
- **作品聚合**：同一作品的多卷漫画可以合并成一张作品卡，进入后再查看所有卷；默认快捷分类为“全部、作品、已下载、未下载”，长按“分类筛选”可以自定义。
- **自定义下载目录**：可以选择并验证新的可写目录。切换只影响新下载，不会移动旧漫画；原目录中的文件仍能识别、打开和删除。
- **更完整的下载管理**：按磁盘真实状态显示已完成、未完成或文件已删除，支持删除本地漫画、清理 `.part` 临时文件、移除失效记录及批量清理。
- **继续阅读双页预览**：打开书封面贴合弧形纸面。阅读已下载漫画后，每本在本机最多保留最近两张低分辨率画面，用于书架左右页预览；删除漫画时会同步清理。
- **更新窗口修复**：较长的更新说明可以滚动阅读，“稍后更新”和“立即更新”按钮始终保留在底部；下载和安装仍必须由用户确认。
- **网络与安全**：优化部分旧 Kindle 的网络等待错误处理，并继续校验 HTTPS 证书、域名、更新包大小和 SHA-256。插件不收集安装量、设备型号或其他遥测信息。

完整的逐项说明见 [v0.4.2 Release](https://github.com/jackchensky/KooComic/releases/tag/v0.4.2)。在线更新后需要完整重启 KOReader 才会启用新版本。

## 安装

### 通过 Storefront

1. 打开 KOReader 的 Storefront，使用默认的 **Storefront** 目录来源。
2. 刷新插件目录。
3. 搜索 `KooComic`、`KOOBONE` 或“漫画”并安装。

如果 Direct GitHub API 模式暂时搜不到，请切回默认 Storefront 目录。GitHub Topic 搜索存在分页、缓存和未认证请求限速，可能漏掉少量仓库。

### 手动安装

1. 从 [Releases](https://github.com/jackchensky/KooComic/releases/latest) 下载最新版 ZIP。
2. 解压后，将整个 `koocomic.koplugin` 文件夹复制到 `koreader/plugins/`。
3. 完全重启 KOReader，然后打开 `工具 → Koo可漫`。

从 v0.3.1 或更早版本升级时，只删除旧的 `plugins/koobone.koplugin` **插件代码目录**；不要删除 `settings/koobone.lua` 和原有漫画下载目录，以便迁移登录状态与本地文件。升级前建议先备份这两处数据。

## 在线更新

插件从 GitHub Pages 读取固定版本清单，并通过 GitHub Release 下载更新包。发现新版本后，会先询问是否更新；只有确认后才会下载、校验和安装。

在线更新地址、更新提醒规则和完整功能说明见 [`koocomic.koplugin/README.md`](koocomic.koplugin/README.md)。开发与真机验证进度见 [`PROJECT_STATUS.md`](PROJECT_STATUS.md)。

## 隐私与安全

- 插件不包含安装量、设备型号或其他遥测统计。
- API Key 和短期会话只保存在 Kindle 本机设置文件中，请勿分享设置文件或未经脱敏的备份。
- 退出账号会清除 API Key、会话及旧版遗留密码，不删除已下载漫画。
- 请勿在 Issue 中上传密码、Cookie、完整签名下载地址或未脱敏日志。
- 提交截图前，请遮盖账号、邮箱和其他个人信息。

本项目依据 KOOBONE 提供的 API Key 接口说明开发；接口后续调整或不同设备的网络环境仍可能导致部分功能暂时失效。如果遇到问题，请在 [Issues](https://github.com/jackchensky/KooComic/issues) 中说明 Kindle 型号、KOReader 版本、插件版本和已脱敏的错误信息。

参与开发前请阅读 [`CONTRIBUTING.md`](CONTRIBUTING.md)。涉及账号、会话、更新校验或其他安全问题时，请不要公开细节，改按 [`SECURITY.md`](SECURITY.md) 私密报告。

## English

**KooComic·可漫** is an independently developed KOReader connector that uses the API Key interface scheme provided by KOOBONE to access the user's personal comic library. It provides an e-ink-friendly cover shelf, search and filters, EPUB downloads with progress, local cover caching, account controls, adaptive layouts, and verified in-app updates. It is not a KOOBONE official client; its interface, features, releases, and support are maintained by this project.

Install it from KOReader Storefront, or download the latest package from [GitHub Releases](https://github.com/jackchensky/KooComic/releases/latest). Device compatibility may vary; privacy-safe reports are welcome in [Issues](https://github.com/jackchensky/KooComic/issues).

## 许可证与声明

本项目采用 [GNU Affero General Public License v3.0 only](LICENSE)，SPDX 标识为 `AGPL-3.0-only`。

本项目使用 KOOBONE 提供的 API Key 接口方案；插件本身由本项目独立开发和维护，不是 KOOBONE 官方客户端。KOOBONE 名称用于说明所连接的服务与接口来源。

# 安全政策

KooComic·可漫会处理 KOOBONE API Key、短期登录会话、旧版可能遗留在本机的密码，以及 GitHub Release 在线更新。请不要在公开 Issue 中披露可能影响用户账号或更新安全的细节。

## 支持范围

| 版本 | 安全更新 |
| --- | --- |
| 最新公开版本 | 支持 |
| 更早版本 | 请先升级后复测 |

## 私密报告安全问题

请前往仓库的 **Security → Advisories → Report a vulnerability** 创建私密报告：

https://github.com/jackchensky/KooComic/security/advisories/new

建议提供：

- 受影响的插件和 KOReader 版本；
- 问题类型、影响范围和最小复现步骤；
- 已删除真实账号、密码、Cookie、会话值和完整签名 URL 的验证信息；
- 如果已有修复思路，可附上建议，但不要先公开利用细节。

如果页面暂时没有私密报告入口，请只创建一个不含技术细节和敏感数据的公开 Issue，说明“需要私密安全联系渠道”，等待维护者回复。

以下问题应优先使用私密报告：

- 密码、Cookie 或会话信息意外写入日志、截图或仓库；
- 登录状态被错误共享或未能在退出时清除；
- 在线更新的 SHA-256 校验、下载来源限制、解压路径或回滚可被绕过；
- 可导致任意文件覆盖、代码执行或未授权访问的缺陷。

普通界面问题、下载超时和不包含敏感信息的兼容性问题，请使用公开的错误反馈表单。

## English summary

Do not disclose credential, session, update-verification, path-traversal, or code-execution issues in public issues. Use GitHub private vulnerability reporting and remove all real credentials, cookies, session values, signed URLs, and personal information from evidence.

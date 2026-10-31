# 参与贡献

感谢你愿意帮助改进 KooComic·可漫。本项目优先保证账号安全、Kindle 真机兼容性和可恢复的更新流程。

## 提交问题

请先搜索现有 Issue，再选择“错误反馈”或“功能建议”表单。错误反馈最好包含：

- Kindle 或其他设备型号；
- KOReader 和 Koo可漫版本；
- 安装方式、复现步骤、预期结果与实际结果；
- 只与问题相关的已脱敏日志。

不要公开密码、Cookie、账号、会话值、完整签名下载地址或未遮盖个人信息的截图。安全问题请按 [`SECURITY.md`](SECURITY.md) 私密报告。

## 本地验证

插件面向 KOReader 的 Lua 5.1/LuaJIT 兼容环境。提交代码前，请至少运行：

```bash
find koocomic.koplugin spec -type f -name '*.lua' -print0 | xargs -0 -n1 luac5.1 -p
for spec_file in spec/*_spec.lua; do lua5.1 "$spec_file"; done
```

如果修改了打包或版本更新逻辑，还应使用当前 `_meta.lua` 版本执行 `scripts/package_release.sh`，并检查 ZIP 完整性、SHA-256 和 `update.json`。GitHub CI 会重复执行这些检查。

## Pull Request 原则

- 一次 PR 尽量只解决一个明确问题。
- 不要顺手删除旧设置迁移、旧版 KOReader 列表回退或失败回滚。
- 修改界面时，请说明验证过的设备型号、KOReader 版本和屏幕方向。
- 不要为了测试访问或提交真实账号数据；测试只使用 `.example.test` 等虚构值。
- 实质性修改应同步更新 `PROJECT_STATUS.md`；只有准备发布时才提升插件版本。
- 新增依赖或网络服务前，说明必要性、维护风险和隐私影响。

所有贡献均按照项目的 [`AGPL-3.0-only`](LICENSE) 许可证发布。

## English summary

Please search existing issues and use the provided forms. Include device, KOReader and plugin versions, reproduction steps, and privacy-safe logs. Never post credentials, cookies, session values, signed download URLs, or unredacted screenshots. Run the Lua 5.1 syntax checks and standalone specs before opening a pull request. Contributions are licensed under `AGPL-3.0-only`.

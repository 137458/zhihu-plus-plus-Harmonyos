# HarmonyOS Agent Instructions

本仓库是 Zhihu++ 的 HarmonyOS NEXT 原生移植工程，使用 ArkTS、ArkUI、Stage 模型、Hvigor 和 OHPM。

## Agent skills

### Issue tracker

问题和 PRD 使用 GitHub Issues 管理，使用 `gh` CLI 操作。See `docs/agents/issue-tracker.md`.

### Triage labels

使用 `needs-triage`、`needs-info`、`ready-for-agent`、`ready-for-human` 和 `wontfix` 五个分流标签。See `docs/agents/triage-labels.md`.

### Domain docs

使用 single-context 布局，先阅读根目录 `CONTEXT.md` 和相关 `docs/adr/`。See `docs/agents/domain.md`.

## HarmonyOS 约定

- 生产基线为 API 24 Release，不因 Android 代码结构直接引入 Gradle、Compose、Room 或 Kotlin 依赖。
- 使用 Stage 模型、`Navigation`、`NavPathStack` 和显式 ArkTS 类型。
- 不使用 `any`、`unknown` 或未经确认的动态对象结构。
- 页面只负责 UI 组合和用户操作编排；网络、会话、协议解析和持久化放在对应边界内。
- 复杂正文首版使用 ArkWeb，必须限制 HTTPS、可信主机和桥接方法。
- 迁移功能先确认 Android 行为和协议证据，再实现 HarmonyOS 版本。
- 每次修改后检查 debug、release、ohosTest 和对应真机或模拟器验证范围。
- 生成目录、本机配置、账号凭据、Cookie、Token、签名文件和日志不得提交。

## 目录边界

- `entry/`：HarmonyOS 主 HAP 和应用代码。
- `docs/`：HarmonyOS 专属计划、工程说明和 ADR。
- `zhihu-plus-plus/`：Android/Kotlin 参考工程，只用于行为、协议和功能取证。

上级目录和 Android 参考工程不是 HarmonyOS 构建依赖。HarmonyOS 代码、配置、资源和文档只提交本仓库范围内的文件。

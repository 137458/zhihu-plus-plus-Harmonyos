# HarmonyApp Context

## 项目定位

HarmonyApp 是 Zhihu++ Android 客户端的 HarmonyOS NEXT 原生移植工程。它不是 Android/Kotlin Multiplatform 工程的编译包装，也不直接复用 Compose、Room、Gradle 或 Android WebView。

## 技术基线

- 应用模型：Stage
- 语言：ArkTS
- UI：ArkUI
- SDK：HarmonyOS 6.1.1 API 24 Release
- 构建：Hvigor
- 依赖：OHPM
- 主模块：`entry`
- 设备：phone、tablet

## 领域术语

- **核心阅读链路**：首页信息流、搜索、问题详情、回答详情、文章详情和正文展示。
- **会话**：登录凭据、ArkWeb Cookie、请求认证状态以及退出时的清理边界。
- **正文容器**：承载 HTML、Markdown、图片、表格、代码和 LaTeX 的 ArkWeb 组件。
- **纵向切片**：从页面入口、状态、网络、存储到测试均可独立验收的功能批次。
- **参考工程**：`zhihu-plus-plus/` Android/Kotlin 工程，只提供行为、协议和功能证据。

## 架构边界

- 页面不能直接拼接协议请求或持久化敏感数据。
- 网络客户端负责请求、响应和错误模型；页面只消费明确模型。
- 会话凭据不得写入日志、源码、普通 preferences 或脱敏样本。
- ArkWeb 只处理正文或受控登录页面，不作为跨层业务状态仓库。
- Android 代码只有在行为和协议得到确认后，才能转换为 ArkTS 实现。

## 当前交付规划

迁移分为 11 批：第 0–8 批完成核心 HarmonyOS 产品和发布收口，第 9–11 批补齐完整社区、智能能力、发布增强及 HarmonyOS 生态能力。详细时间、功能和验收标准见 `docs/Android到HarmonyOS移植计划.md`。

## 当前进度

| 批次 | 状态 | 说明 |
|---|---|---|
| 第 0 批 证据与范围冻结 | 已完成 | `docs/evidence/` 下 6 份证据文档：首发范围、鉴权、首页搜索、详情、互动、接口清单、风险清单 |
| 第 1 批 HarmonyOS 主壳 | 已完成 | 主壳 `Index.ets` + 6 组件（AppTitleBar/LoadingView/EmptyView/ErrorView/PlaceholderPage/AppToast）+ 8 占位页面 + 路由契约 + 断点/Toast 工具 + 资源基线 + UiTest |
| 第 2 批 匿名信息流与搜索 | 未开始 | 下一批：NetworkClient、首页推荐、搜索 |

## 工程结构（截至第 1 批）

```
entry/src/main/ets/
├─ entryability/         Ability 生命周期
├─ entrybackupability/   备份 Ability
├─ pages/                Index 主壳 + 8 个占位页面
├─ components/           6 个统一组件
├─ router/               AppRouter 路由契约
├─ utils/                BreakpointUtil、ToastUtil
└─ model/                （预留，第 2 批启用）
   viewmodel/            （预留，第 2 批启用）
   api/                  （预留，第 2 批启用）
   web/                  （预留，第 3 批启用）
   storage/              （预留，第 4 批启用）
```

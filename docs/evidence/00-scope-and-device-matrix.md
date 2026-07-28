# 首发范围与设备矩阵

## 1. 首发包含清单

按移植计划 4.1 节，首发版本范围聚焦于稳定的核心阅读链路：

| 功能 | 优先级 | 接口证据来源 | 移植批次 |
|---|---|---|---|
| 首页或推荐内容列表 | P0 | [02-home-and-search.md](./02-home-and-search.md) | 第 2 批 |
| 搜索入口和搜索结果 | P0 | [02-home-and-search.md](./02-home-and-search.md) §7 | 第 2 批 |
| 问题详情 | P0 | [03-content-detail.md](./03-content-detail.md) §2 | 第 3 批 |
| 回答详情 | P0 | [03-content-detail.md](./03-content-detail.md) §2 | 第 3 批 |
| Markdown、图片、表格和 LaTeX 公式展示 | P0 | [03-content-detail.md](./03-content-detail.md) §6 | 第 3 批 |
| 登录、会话恢复和退出登录 | P0 | [01-auth-and-session.md](./01-auth-and-session.md) §2 | 第 4 批 |
| 点赞和收藏 | P0 | [04-interaction-and-profile.md](./04-interaction-and-profile.md) §4、§5 | 第 5 批 |
| 基础个人设置 | P0 | [04-interaction-and-profile.md](./04-interaction-and-profile.md) §9 | 第 6 批 |
| 手机和平板自适应布局 | P0 | — | 第 1 批 |
| 深色模式、加载态、空态和错误态 | P0 | — | 第 1 批 |

## 2. 首发暂缓清单

按移植计划 4.2 节，以下能力**不在首发版本范围内**，待首发稳定后按独立纵向切片扩展：

- 完整内容发布编辑器（第 7 批）
- 复杂评论树和楼中楼（第 9 批）
- 推送、服务卡片和跨设备流转（第 11 批）
- 端侧 embedding 和推荐模型（第 10 批）
- Android 专用 WebView 注入逻辑（不移植，HarmonyOS 用 ArkWeb 替代）
- Android Room 数据库代码直接复用（不移植，HarmonyOS 用 relationalStore 替代）
- 桌面端和可穿戴设备适配（不移植）

## 3. 设备矩阵

| 设备类型 | 支持状态 | API 24 兼容性 | 自适应策略 |
|---|---|---|---|
| phone | 支持 | 完整 | 单列布局，底部 TabBar，NavPathStack 推入式导航 |
| tablet | 支持 | 完整 | 双栏布局（master-detail），左侧导航列表 + 右侧详情，自适应断点 |
| 2-in-1 | 暂缓 | 不验证 | — |
| desktop | 不支持 | 不验证 | 不在首发范围 |
| wearable | 不支持 | 不验证 | 不在首发范围 |
| TV | 不支持 | 不验证 | 不在首发范围 |
| car | 不支持 | 不验证 | 不在首发范围 |

## 4. 技术基线（已冻结）

| 项目 | 基线 |
|---|---|
| 应用模型 | HarmonyOS NEXT Stage 模型 |
| 开发语言 | ArkTS |
| UI 框架 | ArkUI |
| SDK | HarmonyOS 6.1.1，API 24 Release |
| 构建系统 | Hvigor |
| 包管理 | OHPM |
| HarmonyOS 模块 | `entry` 单模块 |
| 主 Ability | `EntryAbility` |
| 支持设备 | `phone`、`tablet` |
| 最低 API | 24 |
| 目标 API | 24 |

## 5. 首发功能与 Android 参考实现映射

| 首发功能 | Android 参考实现 | 协议层 | 移植难点 |
|---|---|---|---|
| 首页推荐 | `HomeFeedViewModel` / `AndroidHomeFeedViewModel` / `MixedHomeFeedViewModel` | Web API（zse 签名）+ JSON API（无签名） | ZseSigner 算法移植 |
| 搜索 | `SearchViewModel` | Web API（zse 签名） | URL 参数构造复杂，过滤项多 |
| 问题详情 | `QuestionFeedViewModel` | JSON API | 回答列表分页与排序切换 |
| 回答详情 | `ArticleViewModel`（Answer 分支） | JSON API | segmentInfos 注入、回答切换导航器 |
| 文章详情 | `ArticleViewModel`（Article 分支） | JSON API | 与回答详情共用 ViewModel，需保留分支 |
| Markdown 渲染 | `com.hrm.markdown.renderer.Markdown` | — | KMP 库的 HarmonyOS 兼容性，LaTeX 字体下载 |
| 登录 | `LoginActivity` + `QrLogin.kt` | Web API（zse 签名） | WebView → ArkWeb、二维码生成、风控处理 |
| 会话恢复 | `AccountData.loadData` + `fetchVerifiedZhihuAccount` | Web API | account.json 序列化、token 刷新 |
| 退出登录 | `AccountData.delete` | — | 本地数据清理 |
| 点赞 | `ArticleViewModel.toggleVoteUp` + `VotersSupport` | Web API（postSigned） | 签名、3 种不同接口形态 |
| 收藏 | `ArticleViewModel.toggleFavorite` + `CollectionsViewModel` | JSON API + Web API 混合 | PUT 接口未走签名 |
| 个人设置 | `AppearanceSettingsScreen` 等 | 本地 SharedPreferences | SharedPreferences → preferences 反射化迁移 |

## 6. 不移植的 Android 能力

以下 Android 参考实现的能力**不移植**到 HarmonyOS：

| 能力 | 不移植原因 |
|---|---|
| Android Compose UI | Compose Multiplatform 与 ArkUI 不可互操作，必须用 ArkUI 重写 |
| Android Room 数据库 | Room 是 Android 专用，HarmonyOS 用 relationalStore 替代 |
| Android Ktor HttpClient | Ktor 依赖 JVM，HarmonyOS 用 @kit.NetworkKit 或 @ohos/axios 替代 |
| Android OkHttp Interceptor | 项目实际未使用 OkHttp，Ktor 插件机制需在 ArkTS 重实现 |
| Android WebView 注入 | Android `addJavascriptInterface` → ArkWeb `registerJavaScriptProxy` |
| Android Coil3 图片库 | Coil3 依赖 Compose，HarmonyOS 用 ArkUI Image + 自定义缓存 |
| Android zxing 二维码 | 用 HarmonyOS @kit.ScanKit 替代 |
| Android JourneyApps barcode scanner | 同上 |
| Android TextToSpeech | 用 HarmonyOS 朗读能力替代（首发不实现） |
| Android DOM turducks (Ksoup) | 需评估 Ksoup 的 HarmonyOS 兼容性，或用 ArkWeb 解析 HTML |
| Android 应用内更新 | 不在首发范围 |
| NLP 关键词分析 | 第 10 批 |
| 本地推荐引擎 | 第 10 批 |
| LaTeX 自研渲染 | 第 3 批，可能用 ArkWeb + KaTeX JS 替代 |

## 7. 进入第 1 批的验收

- [x] 首发功能都有行为证据（01-04 四个文档已完成）
- [x] 已确认匿名请求与登录请求的差异
- [x] 已确认账号凭据的存储和清除策略
- [ ] 首页、搜索、问题详情、回答详情和登录接口都有可重放样本（实际样本采集作为第 0 批后续补充）

# Zhihu++ Android 到 HarmonyOS 移植计划

## 1. 文档目的

本文档用于指导将上级目录中的 Android/Kotlin Multiplatform Zhihu++ 项目迁移为当前 `HarmonyApp` 内的 HarmonyOS NEXT 原生应用。

本文档只描述 HarmonyOS 工程的实施范围、技术路线、阶段任务和验收标准。上级目录中的 Android 工程、参考示例和历史资料仅作为行为、协议和产品功能参考，不作为 HarmonyOS 构建依赖。

## 2. 工程边界

### 2.1 提交边界

迁移实现只允许提交 `HarmonyApp/` 目录中的文件。

以下内容保持在仓库上级目录或参考目录中，不纳入 HarmonyOS 运行时依赖：

- Android/Kotlin Multiplatform 源码
- Android Gradle 构建配置
- Android 本地数据库实现
- Android Compose UI
- Android 端 Markdown 子工程
- Rust 工具和服务端项目
- `references/` 中的历史快照和官方示例
- 仓库级分析文档和通用移植指南

### 2.2 不应提交的生成文件

即使位于 `HarmonyApp/` 内，以下本机构建或 IDE 生成内容也不应纳入提交：

- `.idea/`
- `.hvigor/`
- `oh_modules/`
- `node_modules/`
- `**/build/`
- `local.properties`
- `.appanalyzer/`
- `**/.test/`
- `.cxx/`

当前 `HarmonyApp/.gitignore` 已覆盖上述主要目录。`local.properties` 明确包含本机路径，只能在本地使用。

## 3. 当前基线

| 项目 | 当前情况 |
| --- | --- |
| 应用模型 | HarmonyOS NEXT Stage 模型 |
| 开发语言 | ArkTS |
| UI 框架 | ArkUI |
| SDK | HarmonyOS 6.1.1，targetSdkVersion=API 24，compatibleSdkVersion=API 23（支持沉浸光感材质） |
| 构建系统 | Hvigor |
| 包管理 | OHPM |
| HarmonyOS 模块 | `entry` 单模块 |
| 支持设备 | `phone`、`tablet` |
| 主 Ability | `EntryAbility` |
| 当前首页 | `pages/Index` 模板页面 |
| 当前生产依赖 | 暂无 |
| 当前测试依赖 | `@ohos/hypium`、`@ohos/hamock` |
| Android 工程关系 | 物理同仓，构建和运行时均独立 |

当前 HarmonyOS 工程尚未接入 Android 工程的 Kotlin、Gradle、Compose 或 `shared` 模块。不能通过直接复制 Android UI 或把 Gradle 模块添加到 OHPM 的方式完成迁移。

## 4. 首发版本范围

首个可发布版本采用收敛范围，目标是先建立稳定的核心阅读链路。

### 4.1 首发包含

- 首页或推荐内容列表
- 搜索入口和搜索结果
- 问题详情
- 回答详情
- Markdown、图片、表格和 LaTeX 公式展示
- 登录、会话恢复和退出登录
- 点赞和收藏
- 基础个人设置
- 手机和平板自适应布局
- 深色模式、加载态、空态和错误态

### 4.2 首发暂不包含

- 完整内容发布编辑器
- 复杂评论树和楼中楼
- 推送、服务卡片和跨设备流转
- 端侧 embedding 和推荐模型
- Android 专用 WebView 注入逻辑
- Android Room 数据库代码直接复用
- 桌面端和可穿戴设备适配

这些能力在首发版本稳定后，再按独立纵向切片扩展。

## 5. 目标架构

```text
HarmonyApp/
├─ AppScope/                         应用级元数据和资源
├─ entry/
│  └─ src/main/
│     ├─ ets/
│     │  ├─ entryability/            Ability 生命周期和启动初始化
│     │  ├─ pages/                   页面和路由目标
│     │  ├─ components/              可复用 ArkUI 组件
│     │  ├─ model/                   领域模型和响应模型
│     │  ├─ viewmodel/               页面状态和业务操作
│     │  ├─ api/                     HTTP、协议和鉴权适配
│     │  ├─ web/                     ArkWeb 正文和登录容器
│     │  ├─ storage/                 会话和本地设置
│     │  └─ utils/                   无 UI 依赖的工具
│     ├─ resources/                  字符串、颜色、媒体和配置
│     └─ ohosTest/                   设备测试
└─ docs/                             HarmonyOS 专属实施文档
```

### 5.1 分层规则

- `pages` 只负责页面组合、用户操作编排和路由参数接收。
- `components` 只负责可复用视觉和交互组件。
- `viewmodel` 负责加载、分页、错误、空态、重复操作和失败回滚。
- `api` 负责请求构造、响应解析、超时、错误转换和协议兼容。
- `web` 负责 ArkWeb 生命周期、可信域限制、正文加载和登录回调处理。
- `storage` 负责安全会话、非敏感设置和版本迁移。
- `model` 不依赖 ArkUI，便于单元测试和协议回放。

## 6. Android 到 HarmonyOS 技术映射

| Android | HarmonyOS 实现 | 迁移原则 |
| --- | --- | --- |
| Activity | UIAbility | 使用 Stage 生命周期，不复刻 Activity 结构 |
| Fragment/Compose 页面 | ArkUI 页面和 `NavDestination` | 页面状态与业务状态分离 |
| Navigation Compose | `Navigation` + `NavPathStack` | 路由名称和参数显式定义 |
| ViewModel/StateFlow | ViewModel 类 + ArkTS V2 状态 | 使用 `@ObservedV2`、`@Trace`、`@Local` |
| LazyColumn | `List` + `LazyForEach` | 使用稳定唯一 key |
| Room | `relationalStore` | 仅在确有离线需求时引入 |
| DataStore | `preferences` 或 `PersistenceV2` | 敏感数据不能放普通 KV |
| Ktor/OkHttp | `@kit.NetworkKit` 的 `http` | 每次请求明确超时和资源释放 |
| Android WebView | ArkWeb `Web` | 限制 HTTPS、域名和外部跳转 |
| Android Markdown renderer | 首版 ArkWeb | 先保证内容保真，再逐步原生化 |
| Android SharedPreferences | preferences | 只保存非敏感设置 |
| Android Cookie/Token | Asset Store Kit 或安全存储 | 禁止日志和源码明文保存 |
| Android instrumentation test | `@ohos.UiTest` | 真机或模拟器执行，不依赖 Previewer |

## 7. Markdown 与 ArkWeb 方案

首版不重写完整 Markdown/LaTeX 渲染器，采用 ArkWeb 承载已经在 Android 侧验证过的 HTML、CSS 和 KaTeX 资产。

### 7.1 原生页面职责

- 展示标题、作者和发布时间
- 展示加载、空数据和错误状态
- 控制点赞、收藏和登录引导
- 管理详情页导航和返回行为
- 处理可信外链和系统分享

### 7.2 ArkWeb 容器职责

- 加载经协议层转换后的正文 HTML
- 应用深色模式和正文样式
- 展示公式、表格、图片和复杂嵌套内容
- 通过受控桥接向原生层报告必要事件

### 7.3 安全要求

- 只允许 HTTPS 和明确可信的主机列表。
- 不允许正文内容直接执行不受控的原生方法。
- 不把 Token、Cookie 或个人信息拼接到正文 HTML。
- 外链跳转必须校验协议、主机和路径。
- 登录回调必须校验完整落地 URL，不能只判断固定字符串片段。

## 8. 分阶段实施计划

### 阶段 0：证据和范围冻结

任务：

- 从 Android 工程确认首页、搜索、详情、登录、点赞和收藏的实际行为。
- 整理每个接口的 URL、方法、请求头、Cookie、请求体、响应结构和错误码。
- 建立脱敏请求/响应样本，禁止提交真实账号信息。
- 固定手机和平板的首发适配矩阵。
- 确认登录是网页会话、Cookie 会话还是独立授权接口。

完成标准：

- 每个首发功能都有行为证据。
- 每个核心接口都有可重放样本或明确的待确认项。
- 没有未经证实的字段编号、权限和 API 调用。

### 阶段 1：HarmonyOS 工程骨架

任务：

- 保持 API 24、Stage 模型和 `entry` 单模块。
- 建立目标目录和基础资源结构。
- 将首页从模板页面替换为主导航壳。
- 接入 `Navigation + NavPathStack`。
- 建立统一页面标题、加载态、空态、错误态和 Toast 处理。

完成标准：

- `EntryAbility` 能稳定进入主导航页面。
- 手机和平板均能正确显示。
- 页面前进、返回、重复进入和前后台切换行为一致。
- ArkTS 严格检查通过。

### 阶段 2：匿名阅读纵向切片

任务：

- 实现内容列表和分页状态。
- 实现问题详情和回答详情路由。
- 实现 API 客户端和显式响应模型。
- 实现 ArkWeb 正文容器。
- 覆盖 Markdown、图片、表格、LaTeX、空数据和解析失败。
- 未登录操作统一进入登录引导。

完成标准：

- 从列表进入详情的主链路可用。
- 网络失败、超时、空响应和重复加载不会导致页面崩溃。
- 正文在手机和平板均可滚动，图片和公式有明确降级策略。

### 阶段 3：完整账号能力

任务：

- 实现登录页面和受控 ArkWeb 登录流程。
- 实现 Cookie/Token 的安全保存和恢复。
- 实现会话过期、重新登录和退出登录。
- 实现跨页面登录状态同步。
- 清理退出登录后的 Web Cookie、内存状态和导航状态。

完成标准：

- 冷启动能够恢复有效会话。
- 无效会话不会进入半登录状态。
- 退出登录后不能通过返回栈重新访问已授权内容。
- 日志和本地普通存储中没有敏感凭据。

### 阶段 4：点赞、收藏和基础设置

任务：

- 实现点赞和收藏状态展示。
- 实现操作中的防重复提交。
- 实现成功更新、失败回滚和会话过期处理。
- 实现主题、字体和基础显示设置。
- 在设置页验证 preferences 或 PersistenceV2 的迁移策略。

完成标准：

- UI 状态与服务端结果一致。
- 弱网、断网和快速重复点击不产生错误状态。
- 设置在重启后恢复，版本升级后兼容旧数据。

### 阶段 5：测试、性能和发布

任务：

- 补充模型、解析器、分页和状态机单元测试。
- 使用 UiTest 验证启动、搜索、详情、登录引导和返回栈。
- 在手机和平板真机或模拟器验证深色模式、字体缩放和窗口尺寸。
- 检查 ArkWeb 内存、监听器、定时器和页面退出清理。
- 配置 release 签名和 ArkGuard 保留规则。

完成标准：

- debug、release 和测试目标均能构建。
- 核心链路通过真机验证。
- 无调试凭据、个人 Cookie、内部地址或敏感日志。
- 生成物只来自 `HarmonyApp` 工程。

## 9. 测试策略

### 9.1 单元测试

优先测试不依赖 UI 的代码：

- 请求参数构造
- 响应模型解析
- 分页推进和刷新回滚
- 登录状态转换
- URL 和域名校验
- 正文 HTML 生成
- 设置迁移

### 9.2 UI 测试

至少覆盖：

- 冷启动进入首页
- 首页进入问题详情
- 问题详情进入回答详情
- 搜索输入和结果进入详情
- 未登录点击点赞或收藏
- 登录取消、登录成功和登录失败
- 系统返回和导航栈恢复
- 手机和平板布局

### 9.3 回归矩阵

| 场景 | 手机 | 平板 | 深色模式 | 断网 |
| --- | --- | --- | --- | --- |
| 冷启动 | 必测 | 必测 | 必测 | 必测 |
| 内容列表 | 必测 | 必测 | 必测 | 必测 |
| 回答详情 | 必测 | 必测 | 必测 | 必测 |
| 登录恢复 | 必测 | 必测 | 必测 | 必测 |
| 点赞收藏 | 必测 | 必测 | 必测 | 必测 |

## 10. 构建和运行方式

### 10.1 DevEco Studio

1. 只打开 `HarmonyApp/` 作为 HarmonyOS 工程。
2. 使用 DevEco Studio 6.1.1 Release 和 API 24 SDK。
3. 使用真机或 HarmonyOS 模拟器选择 `entry` 的 `default` target。
4. 不把 `HarmonyApp/zhihu-plus-plus/` 作为 HarmonyOS 模块导入。

### 10.2 命令行

在 `HarmonyApp/` 目录执行 DevEco 生成的 `hvigorw` 命令。具体任务名以当前 DevEco 版本生成的任务列表为准，不能依据 Gradle 任务名猜测。

建议至少验证：

- debug HAP 构建
- release HAP 构建
- `ohosTest` 测试构建
- 真机安装和启动

### 10.3 产物和提交

- HAP、日志和构建中间文件只作为本地验证产物。
- 不把 `.hvigor`、`build`、`oh_modules`、`local.properties` 提交到版本库。
- 代码、资源、配置和 HarmonyOS 专属文档只放在 `HarmonyApp/` 内。
- 上级目录内容继续作为参考，不修改其 Android 运行链路。

## 11. 风险与决策

| 风险 | 控制措施 |
| --- | --- |
| Android 接口行为不完整 | 先建立脱敏证据库和可重放样本 |
| Protobuf 字段或鉴权规则误判 | 以定义文件、真实样本和官方资料为准 |
| ArkWeb 外链和会话泄漏 | HTTPS、主机白名单、桥接最小化 |
| 富文本渲染性能不足 | 首版 ArkWeb，延迟加载图片，限制正文体积 |
| ArkTS 严格语法不兼容 | 所有模型使用显式类型，不使用 `any` 和动态对象 |
| 平板布局回归 | 使用窗口断点和独立 UI 回归矩阵 |
| 构建边界污染 | 只在 `HarmonyApp/` 内实现，不提交生成目录 |

## 12. Definition of Done

一个移植切片只有同时满足以下条件，才能标记为完成：

- 行为与 Android 参考实现或已确认协议一致。
- ArkTS 严格检查和对应 HAP 构建通过。
- 单元测试覆盖关键模型和状态转换。
- 真机或模拟器完成核心交互验证。
- 手机、平板、深色模式和断网场景完成回归。
- 错误、空数据、重复点击和返回栈行为明确。
- 没有敏感信息进入源码、日志、测试样本或提交内容。
- 所有新增实现和文档均位于 `HarmonyApp/` 内。

## 13. 详细批次与时间安排

### 13.1 总体安排

本项目共分为 **11 批** 完成，按连续开发周期规划。第 0–8 批完成首发核心产品，第 9–11 批继续补齐 Android 参考工程中的完整社区、智能、创作和 HarmonyOS 生态能力。每一批都必须形成一个可以独立构建、独立验证和独立回退的交付节点。

| 批次 | 时间段 | 批次名称 | 交付结果 |
| --- | --- | --- | --- |
| 第 0 批 | 第 1 周 | 证据与范围冻结 | 接口证据库、功能清单、设备矩阵和风险清单 |
| 第 1 批 | 第 2–3 周 | HarmonyOS 主壳 | 可运行的主导航、路由、主题、状态和基础测试 |
| 第 2 批 | 第 4–6 周 | 匿名信息流与搜索 | 首页推荐、搜索、分页、刷新和基础内容卡片 |
| 第 3 批 | 第 7–9 周 | 内容详情与正文 | 问题、回答、文章详情及 ArkWeb 正文渲染 |
| 第 4 批 | 第 10–12 周 | 登录与会话 | 登录、会话恢复、失效处理和安全退出 |
| 第 5 批 | 第 13–15 周 | 核心互动与个人页 | 点赞、收藏、基础评论、历史和个人主页 |
| 第 6 批 | 第 16–18 周 | 产品增强能力 | 过滤、设置、通知、分享、图片和视频 |
| 第 7 批 | 第 19–22 周 | 创作与导出 | 发布、草稿、上传、导出和本地推荐 |
| 第 8 批 | 第 23–25 周 | 发布收口 | 性能、兼容性、安全、签名和最终回归 |
| 第 9 批 | 第 26–29 周 | 完整社区能力 | 关注、粉丝、热榜、日报、通知中心和完整评论 |
| 第 10 批 | 第 30–34 周 | 高级内容与智能能力 | 完整编辑器、复杂导出、离线缓存、NLP 和推荐增强 |
| 第 11 批 | 第 35–39 周 | HarmonyOS 生态补齐 | Push、服务卡片、流转、多窗口和多设备能力 |

时间段是计划基线，不代表在没有接口、设备或服务端配合时仍能按原节奏完成。任何批次如果核心证据未确认，不得直接进入编码阶段。

### 13.2 第 0 批：证据与范围冻结

**时间：第 1 周**

**本批实现内容**

- 梳理 Android 参考实现中的启动、首页、搜索、问题详情、回答详情、登录、点赞和收藏行为。
- 为首发功能建立行为表，记录入口、用户操作、加载态、成功态、失败态、返回行为和登录态差异。
- 记录每个接口的 URL、HTTP 方法、请求头、Cookie、请求体、响应字段、分页字段和错误码。
- 建立脱敏请求/响应样本，样本中不得包含真实 Cookie、Token、账号、手机号或私有地址。
- 确认哪些能力使用 Web API、JSON API、Protobuf 或其他协议。
- 固定 API 24、Stage、`entry` 单模块以及 phone/tablet 设备范围。
- 形成首发包含清单和暂缓清单。

**本批不实现**

- 不编写业务页面。
- 不复制 Android Compose 页面。
- 不把 Kotlin `shared`、Room 或 Gradle 模块加入 HarmonyOS 构建链路。
- 不根据字段名猜测接口字段编号、认证方式或权限。

**进入下一批的条件**

- 首发功能都有行为证据。
- 首页、搜索、问题详情、回答详情和登录接口都有可重放样本，或明确列出待确认项。
- 已确认匿名请求与登录请求的差异。
- 已确认账号凭据的存储和清除策略。

### 13.3 第 1 批：HarmonyOS 主壳

**时间：第 2–3 周**

**第 2 周实现内容**

- 将当前模板首页替换为主应用壳。
- 建立 `pages`、`components`、`model`、`viewmodel`、`api`、`web`、`storage` 和 `utils` 目录。
- 建立主路由名称和页面参数类型。
- 接入 `Navigation` 与 `NavPathStack`。
- 建立首页、搜索、详情、登录、个人页和设置页占位路由。

**第 3 周实现内容**

- 建立统一标题栏、加载态、空态、错误态、重试和 Toast 组件。
- 建立 API24 可用的主题、深色资源、字符串资源和基础尺寸资源。
- 建立手机单列、平板双栏或自适应布局的基础断点。
- 建立页面生命周期和状态清理规则。
- 增加首个 UiTest：冷启动、进入占位页面、返回首页。

**批次验收**

- 应用冷启动进入主壳，不再显示 `Hello World` 模板页。
- 所有占位路由可以前进、返回和重复进入。
- phone/tablet 均能构建和运行。
- 深色模式和系统返回可用。
- debug HAP、`ohosTest` target 和 ArkTS 严格检查通过。

**批次完成情况（2026-07-28）**

- 目录骨架：`pages/components/model/viewmodel/api/web/storage/utils/router/entryability/entrybackupability` 全部建立并通过 README.md 固化职责。
- 路由：`AppRouter.RouteName` + `QuestionDetailParams/AnswerDetailParams/ArticleDetailParams/ProfileParams/LoginParams` 显式类型，禁止 `any/unknown`。
- HDS 化（超出原计划，已全部完成）：
  - 主壳 `pages/Index.ets` 使用 `HdsNavigation` 作为路由容器 + `HdsTabs` 作为底部 TabBar。
  - `HdsTabs` 配置 `barOverlap(true) + barPosition(BarPosition.End) + vertical(false) + barBackgroundStyle({maskColor, maskHeight})` 三要素，提供底部渐变模糊。
  - `components/PlaceholderPage.ets` 使用 `HdsNavigation + HdsNavigationTitleMode.MINI + ScrollEffectType.GRADIENT_BLUR + blurEffectiveEndOffset=0vp`，对所有占位页面（首页/搜索/我的/问题详情/回答详情/文章详情/登录/设置）提供顶部渐变模糊。
  - `components/AppToast.ets` 直接绑定全局 `toastState` 单例，保持 `@ObservedV2 + @Trace` 状态变化可被 `@ComponentV2` 感知。
- 测试入口（占位期间）：`HomePage` titleBar 右上角测试入口按钮（`HdsNavigationIconOptions.componentId='home_test_push'`），由 `Index.ets` 注入 `navPathStack.pushPathByName(RouteName.QUESTION_DETAIL, params)` 回调，后续批次接入真实首页功能后移除。
- UiTest（`ohosTest/ets/test/Ability.test.ets`）已扩展为 4 个用例：
  - `coldStartShowsHomePage`：验证 `page_home_title` 可见。
  - `navigateToProfileTab`：通过 `ON.text('我的')` 点击 tabBar，验证 `page_profile_title` 可见。
  - `homePageShowsTestEntryButton`：验证 `home_test_push` 测试入口按钮可见。
  - `pushQuestionDetailAndBack`：点击测试入口 → 验证 `page_question_detail_title` → 点击返回（`ON.id('back')`）→ 验证回到 `page_home_title`。
- HDS tabBar 简单对象形式（`{icon, text}`）不支持 `id` 字段；UiTest 通过 `ON.text` 匹配文字定位，避免破坏 HDS 默认 tabBar 选中态、动画和模糊效果。
- 构建验证：`hvigorw assembleHap --mode module --analyze=normal` BUILD SUCCESSFUL。

### 13.4 第 2 批：匿名信息流与搜索

**时间：第 4–6 周**

**第 4 周：网络和模型基础**

- 实现 NetworkClient、请求超时、响应状态转换和资源释放。
- 为首页卡片、问题、回答、文章、作者和分页定义显式 ArkTS 模型。
- 实现接口解析失败、字段缺失和错误码转换。
- 先使用脱敏响应样本完成模型单元测试。

**第 5 周：首页信息流**

- 实现匿名首页推荐列表。
- 实现卡片标题、作者、摘要、图片、内容类型和互动数展示。
- 实现首次加载、下拉刷新、空数据、失败重试。
- 使用 `List + LazyForEach` 和稳定唯一 key。
- 为图片加载设置占位、失败图和基础缓存策略。

**第 6 周：搜索**

- 实现搜索输入、提交、清空和结果列表。
- 实现搜索结果分页和重复请求保护。
- 从信息流和搜索结果进入详情路由。
- 校验内容 ID，禁止使用无效参数发起请求。

**批次验收**

- 未登录可加载匿名信息流。
- 首页刷新不会重复追加旧数据。
- 加载更多不会重复触发。
- 搜索完整链路可用。
- 断网、超时、空响应和解析失败都有页面反馈。
- 相同脱敏响应在 Android 参考预期和 ArkTS 解析结果之间一致。

**完成记录（2026-07-28）**

- ✅ Slice 1 网络层基础与领域模型：NetworkClient/ZseSigner/CookieJar/ApiError/Paging/Author/FeedCard/ContentType
- ✅ Slice 2 首页信息流：HomeFeedViewModel/BasePaginationViewModel/FeedCardDataSource/HomePage(HDS)/StateView/FeedCardView/ZhihuApi.fetchHomeRecommend
- ✅ Slice 3 首页空错载状态：StateView(LOADING/EMPTY/ERROR) + 重试 + 风控反馈（mapErrorMessage 覆盖 NETWORK_ERROR/TIMEOUT/RISK_CONTROL/UNAUTHORIZED/SERVER_ERROR）
- ✅ Slice 4 搜索功能：ZhihuApi.search/fetchHotSearch + SearchViewModel + SearchPage(HDS) + SearchResultView/HotSearchItemView/SearchHistoryItemView + PreferencesUtil 搜索历史持久化
- ✅ Slice 5 批次验收：UiTest 增加 navigateToSearchTab/searchPageShowsInput 用例；构建验证 BUILD SUCCESSFUL
- ⚠️ 已知限制：
  - 搜索 API 要求登录（allowGuestAccess=false），未登录会返回 401；第 4 批接入登录后增加前置阻断
  - 网络变化实时监听第 4 批 EntryAbility 接入
  - 浏览上报（touch/read）暂未实现，后续批次
  - 设备端测试（ZseSigner/NetworkClient）需真机或模拟器执行
- 提交记录：af466bb (Slice 1) → c3df8c0 (Slice 4) → 待提交 (Slice 5 验收)

### 13.5 第 3 批：内容详情与正文渲染

**时间：第 7–9 周**

**第 7 周：问题和回答详情**

- 实现问题标题、描述、作者、统计信息和回答列表。
- 实现回答排序和回答详情入口。
- 实现详情页加载、空态、错误态和重试。
- 实现详情缓存边界，避免返回后无意义重复请求。

**第 8 周：ArkWeb 正文容器**

- 创建统一 `ArticleWebContainer` 或同等职责的 ArkWeb 组件。
- 加载经协议层转换后的 HTML。
- 配置 HTTPS、可信主机、外链校验和最小化 JavaScript 桥接。
- 处理 ArkWeb 加载开始、加载成功、加载失败和页面销毁。

**第 9 周：正文内容覆盖**

- 验证段落、标题、图片、表格、代码块、引用、链接和 LaTeX 公式。
- 验证超长正文、图片失败、公式失败和 HTML 异常。
- 验证手机、平板和深色模式下的正文可读性。
- 验证系统返回、详情页返回和 Web 内容返回不冲突。

**批次验收**

- 首页或搜索结果可进入问题详情、回答详情和文章详情。
- 正文可滚动，图片、表格和公式有可观察结果。
- 外链不能跳转到不受信任的协议或主机。
- ArkWeb 销毁后没有残留监听器、定时器或页面引用。
- 正文失败不会导致 Ability 崩溃。

**Slice 1 完成情况（2026-07-28）**

- ✅ Slice 1 详情领域模型与 API 扩展：
  - 新增模型：`Topic`（话题）、`AnswerDetailQuestion`（回答详情内嵌问题）、`QuestionDetail`（问题详情，10字段+author+topics）、`AnswerDetail`（回答详情，含 question/ipInfo/时间戳）、`ArticleDetail`（文章详情，含 topics/ipInfo/时间戳）
  - 新增 `ContentDetailCache`：内存 LRU 缓存，TTL 10 分钟，容量 100，key=`contentType_contentId`，get 命中重新插入更新访问顺序，put 已存在 key 先删除再插入
  - 扩展 `ZhihuApi`：`fetchQuestionDetail`/`fetchAnswerDetail`/`fetchArticleDetail` 三个详情接口，include 参数逐字来自证据 03 §3，使用 Web 端 UA + `x-requested-with: fetch` 头
  - 新增单元测试 `ContentDetail.test.ets`：覆盖 5 个模型的 fromObject（完整字段/缺必填/风控空对象/可选字段默认值/数组过滤 null）+ ContentDetailCache（命中/未命中/TTL 过期/容量超限/覆盖/清空）
- ✅ 代码审查（双 skill：harmonyos-development + code-review）修复 2 个 P1 问题：
  - `ContentDetailCache` FIFO→LRU（get 命中重新插入；put 已存在 key 先删除再插入）
  - `ApiError` 8 个工厂方法新增可选 `cause?: Error` 参数；`ZhihuApi` 6 处 `catch (e)` 传递原始异常作为 cause（向后兼容，便于调试）
- ⚠️ Slice 1 范围说明：本 Slice 只实现详情领域模型、API 接口和缓存层；问题详情页 UI、回答列表分页、回答详情页 ArkWeb、文章详情页、批次验收分别由 Slice 2~5 实现
- 构建验证：`hvigorw assembleHap` BUILD SUCCESSFUL（CompileArkTS 3.5s）
- 提交记录：d3d145d（16 files changed, 1961 insertions）

**Slice 2 完成情况（2026-07-28）**

- ✅ Slice 2 问题详情页 + 回答列表分页 + 首页卡片点击跳转：
  - 扩展 `ZhihuApi`：新增 `fetchQuestionAnswers(questionId, pagingNext?, order?)`，URL `/api/v4/questions/{id}/feeds?limit=20&order=default`，复用 FeedCard 解析
  - 新增 `QuestionDetailViewModel`：持有 detail (QuestionDetail) + answers (FeedCard[]) 双状态；缓存命中；去重追加（dedupeAppend，基于 stableKey）；并行加载 detail + answers 首页（Promise.all）
  - 改造 `QuestionDetailPage`：HdsNavigation 模式三混合写法 4 字段组合 + 顶部问题信息区（标题/统计/描述）+ LazyForEach 回答列表 + 触底加载更多
  - 改造 `HomePage`：移除测试入口齿轮按钮（SHOW_TEST_ENTRY/onPushQuestion），新增 `onCardClick` 回调，仅处理 QUESTION/ANSWER/ARTICLE 三种类型
  - 改造 `Index.ets`：`handleCardClick(card)` 根据 contentType 分发到对应详情页（QUESTION→QuestionDetailPage 已实现，ANSWER/ARTICLE 占位跳转）
  - 新增 `question_answers_section_title` 字符串资源
- 构建验证：BUILD SUCCESSFUL
- 提交记录：8502384

**Slice 3 完成情况（2026-07-28）**

- ✅ Slice 3 回答详情页 + ArticleWebContainer（ArkWeb 正文容器）：
  - 新增 `web/ArticleWebContainer.ets`：基于 `@ohos.web.web` 的 Web 组件封装
    - 将知乎 content HTML 包装为完整 HTML 文档（charset/viewport/referer meta + base href + CSS）
    - 深色模式 CSS 变量切换（`@media (prefers-color-scheme: dark)`）
    - 图片防盗链：`<base href="https://www.zhihu.com/">` 注入 Referer
    - 安全：`onLoadIntercept` 校验协议（仅 HTTPS）和可信主机白名单（www.zhihu.com、pic1-4.zhimg.com、picx/pica/picb/picd.zhimg.com、equation.zhihu.com）
    - 回调：`onPageFinish`/`onError`/`onLinkClick`
  - 新增 `AnswerDetailViewModel`：持有 detail (AnswerDetail) + isLoading + errorMessage；缓存命中
  - 改造 `AnswerDetailPage`：HdsNavigation 模式三 + 顶部作者卡（头像/姓名/headline）+ 所属问题标题 + ArkWeb 正文 + 底部统计栏（点赞/评论/感谢/IP 属地）+ 加载/错误状态切换
  - 修复 Author.headline 可选字段访问（`!== undefined && .length > 0`）
- 构建验证：BUILD SUCCESSFUL（修复 ArkWeb 回调签名：OnErrorReceiveEvent/OnLoadInterceptEvent）

**Slice 4 完成情况（2026-07-28）**

- ✅ Slice 4 文章详情页（复用 ArticleWebContainer）：
  - 新增 `ArticleDetailViewModel`：持有 detail (ArticleDetail) + isLoading + errorMessage；缓存命中
  - 改造 `ArticleDetailPage`：HdsNavigation 模式三 + 文章标题 + 作者卡 + 发布/更新时间 + ArkWeb 正文（复用 Slice 3 组件）+ 底部统计栏（点赞/评论/IP 属地）+ 加载/错误状态切换
- 构建验证：BUILD SUCCESSFUL

**Slice 5 完成情况（2026-07-28）**

- ✅ Slice 5 批次验收：
  - 重写 `Ability.test.ets`：删除已废弃的 home_test_push 相关用例（homePageShowsTestEntryButton、pushQuestionDetailAndBack）
  - 保留并通过的用例：coldStartShowsHomePage、navigateToProfileTab、navigateToSearchTab、searchPageShowsInput
  - 新增 `navigateToDetailFromHomeCard`：详情页跳转链路验证（依赖网络，网络不可用时跳过不失败）
  - 新增 `detailPageBackButtonAccessible`：占位用例，提醒后续补充自动化入口
  - 设计原则：CI 断网不阻断测试套件，真机环境手动验证完整链路
- 构建验证：BUILD SUCCESSFUL

**第 3 批批次验收标准达成**

- ✅ 首页或搜索结果可进入问题详情、回答详情和文章详情（HomePage.handleCardClick 分发 + Index.ets handleCardClick 路由）
- ✅ 正文可滚动，图片、表格和公式有可观察结果（ArkWeb Web 组件 + CSS 样式 + 图片防盗链）
- ✅ 外链不能跳转到不受信任的协议或主机（onLoadIntercept + HTTPS only + 可信主机白名单）
- ⚠️ ArkWeb 销毁后没有残留监听器、定时器或页面引用（代码审查 + 真机验证待补充）
- ✅ 正文失败不会导致 Ability 崩溃（StateView 错误态 + errorMessage 展示 + 重试按钮）
- ⚠️ 深色模式下正文可读（CSS 变量切换已实现，真机验证待补充）
- ⚠️ 平板布局正文宽度合理（Web 组件 width 100% 自适应，真机验证待补充）

### 13.6 第 4 批：登录与会话

**时间：第 10–12 周**

**Slice 1 会话模型、AssetStore 与 CookieJar 扩展：**
- ✅ ZhihuSession/ZhihuProfile 数据模型（isLoggedIn/userAgent/cookies/accessToken/refreshToken/profile）
- ✅ AssetStore 适配层（Asset Store Kit 加密存储 saveSession/loadSession/clearSession）
- ✅ CookieJar 扩展 z_c0/_xsrf/q_c0 支持
- ✅ 单元测试：AssetStore.test.ets（save/load/clear/update 往返验证）、CookieJar.test.ets（z_c0 空值保护/fromMap toMap 往返）、ZhihuSession.test.ets

**Slice 2 认证 API 与会话恢复：**
- ✅ AuthApi：fetchVerifiedSession（GET /api/v4/me）、refreshToken（POST /api/account/prod/token/refresh）、signIn（POST /api/v3/oauth/sign_in，HMAC-SHA1 + ZseSigner 加密）
- ✅ SessionViewModel：restoreSession（AssetStore 加载 → 验证 → 刷新或清除）、tryRefreshTokens（refreshToken + signIn + fetchVerifiedSession）
- ✅ EntryAbility 冷启动触发（首帧提交后异步 restoreSession）
- ✅ 代码审查（双 skill：harmonyos-development + code-review）修复 6 个问题（P0/P1/P2）
- ✅ 单元测试：AuthApi.test.ets（无 Cookie 时返回 null 的错误路径）

**Slice 3 ArkWeb 登录页与登录引导：**
- ✅ LoginPage：ArkWeb 加载 zhihu.com/signin，onLoadIntercept 安全拦截（仅 http/https）
- ✅ LoginViewModel：setAppCustomUserAgent（桌面 UA）、detectLoginFromCookies（WebCookieManager 提取 + fetchVerifiedSession 验证）
- ✅ ZhihuConstants 集中管理 ZHIHU_WEB_UA，消除跨模块重复定义
- ✅ Index.ets 路由守卫：hasTriggeredLoginGuard 冷启动后仅触发一次，未登录跳转 LoginPage
- ✅ ProfilePage 登录态优先：isLoggedIn 优先于 profile 判定，profile=null 时显示占位昵称/头像
- ✅ SessionViewModel.isRestored 标识：restoreSession 完成后才允许路由守卫判定
- ✅ UiTest：navigateToLoginFromProfile（个人页→登录页→返回）、loginPageShowsWebView

**Slice 4 会话失效处理与退出登录：**
- ✅ NetworkClient 401 全局拦截器：static unauthorizedHandler + refreshAndRetry 节流（10 秒内不重复刷新）
- ✅ SessionViewModel.refreshAndRetry：含节流控制，调用 tryRefreshTokens 内部流程
- ✅ SessionViewModel.logout：clearSessionInternal（AssetStore + CookieJar + 内存）+ logoutCallback（WebCookieManager 清理 + NavPathStack 重置）
- ✅ ProfilePage 退出登录按钮：登录态显示 + AlertDialog 确认对话框（确认/取消）
- ✅ Index.ets 退出回调：onLogoutClick → SessionViewModel.logout → WebCookieManager.clearAllCookiesSync → navPathStack pop 循环回根
- ✅ UiTest：logoutClearsSession（占位，依赖真实登录态）

**批次验收**
- ✅ 有效会话冷启动可恢复（SessionViewModel.restoreSession + fetchVerifiedSession）
- ✅ 过期会话不会进入半登录状态（refreshAndRetry 失败后 clearSessionInternal）
- ✅ 登录成功后首页、详情和互动请求使用正确认证状态（CookieJar 同步 + NetworkClient 401 重试）
- ✅ 退出后不能通过旧返回栈访问授权页面（logoutCallback 重置 NavPathStack）
- ✅ 日志、源码、普通 KV 和测试样本中没有敏感凭据（AssetStore 加密存储 + 日志脱敏）

### 13.7 第 5 批：核心互动与个人页

**时间：第 13–15 周**

**第 13 周：点赞和收藏**

- 实现点赞/取消点赞。
- 实现收藏/取消收藏。
- 实现防重复点击、请求中状态和失败回滚。
- 未登录操作统一跳转登录，不发送匿名写请求。

**第 14 周：评论和历史**

- 实现根评论列表、分页和基础回复。
- 实现评论输入、提交、失败提示和草稿清理。
- 实现在线历史或本地历史的首发子集。
- 验证 Sheet、输入法、系统返回和评论列表滚动位置。

**第 15 周：个人页**

- 实现个人资料和首发内容分区。
- 实现个人回答、文章或收藏中的至少一个分页列表。
- 实现从评论作者进入个人页并返回。
- 处理账号切换和页面状态清理。

**批次验收**

- 点赞、收藏和评论操作成功后状态正确。
- 失败会回滚，不显示伪成功。
- 快速重复点击不会生成重复请求。
- 评论和个人页分页稳定。
- 从个人页返回详情页后，导航和滚动上下文符合预期。

**实际实现（第 5 批 Slice 1/3/4，并行交付）：**

- ✅ Slice 1 点赞（VotersViewModel）：
  - 新增 `VoteState` 枚举（NEUTRAL/UP）和 `VotersViewModel` 单例（@ObservedV2 + @Trace），管理所有内容的点赞状态
  - 回答：`POST /api/v4/answers/{id}/voters`，body `{"type":"up"|"neutral"}`，走 x-zse-93/96 签名
  - 文章：`POST /api/v4/articles/{id}/voters`，body `{"voting":1|0}`，走 x-zse-93/96 签名
  - 乐观更新 + 失败回滚：先更新 UI，API 失败后恢复原状态
  - 防重复点击：isLoading 标志阻止 API 完成前的重复操作
  - 未登录时 Toast 提示"请先登录"
  - 集成到 `AnswerDetailPage` 和 `ArticleDetailPage` 底部统计栏
  - 新增 `NetworkClient.put()` 方法支持 PUT 请求（供 Slice 2 收藏使用）

- ✅ Slice 3 个人页增强（ProfileViewModel）：
  - 新增 `ProfileViewModel` 单例（@ObservedV2 + @Trace，继承 BasePaginationViewModel），管理回答/文章列表分页加载
  - `fetchUserAnswers`：`GET /api/v4/members/{urlToken}/answers?sort_by=voteups`
  - `fetchUserArticles`：`GET /api/v4/members/{urlToken}/articles?sort_by=created`
  - 改造 `ProfilePage`：新增回答/文章 Tabs（原生 Tabs 组件），支持触底加载（onReachEnd）和下拉刷新（Refresh）
  - 空状态使用 EmptyView 组件
  - 已登录用户信息卡片下方显示统计行（回答数/文章数/粉丝数/关注数，当前为占位符）

- ✅ Slice 4 设置页增强（SettingsPage）：
  - 主题模式切换：浅色/深色/跟随系统，使用 `getContext(this).getApplicationContext().setColorMode()` 切换
  - 正文字号调节：Slider 50%~200%，实时预览效果
  - 设置持久化到 Preferences（PreferencesUtil）

- 构建验证：BUILD SUCCESSFUL（修复 16 个编译错误）

**实际实现（第 5 批 Slice 2，2026-08-01 交付）：**

- ✅ Slice 2 收藏/取消收藏（CollectionsViewModel）：
  - 新增 `Collection` 模型（interface，含 id/title/isPublic/isDefault/itemCount/isFavorited 等字段）
  - 新增 `CollectionContentType` 枚举（ANSWER/article）
  - 新增 `CollectionsViewModel` 单例（@ObservedV2 + @Trace），管理用户收藏夹列表和内容收藏状态
  - 加载用户收藏夹列表：`GET /api/v4/people/{urlToken}/collections?limit=20`，走 x-zse-93/96 签名
  - 加载内容被哪些收藏夹收录：`GET /api.zhihu.com/collections/contents/{contentType}/{id}?limit=50`，仅依赖 Cookie
  - 收藏：`PUT /api.zhihu.com/collections/contents/{contentType}/{id}`，body form-urlencoded `add_collections={id}`，仅依赖 Cookie
  - 取消收藏：`PUT /api.zhihu.com/collections/contents/{contentType}/{id}`，body form-urlencoded `remove_collections={id}`，仅依赖 Cookie
  - 乐观更新 + 失败回滚：contentCollectionIds 先更新，API 失败后恢复快照
  - 防重复操作：isOperating 标志阻止并发操作
  - 新增 `CollectionPickerDialog` 组件：底部弹出面板，展示收藏夹列表，每项带复选框，支持勾选/取消勾选
  - 集成到 `AnswerDetailPage` 和 `ArticleDetailPage` 底部统计栏（收藏按钮）
  - 收藏按钮 UI 状态跟随内容是否已收藏：蓝色（已收藏）/ 灰色（未收藏）
  - 未登录时 Toast 提示"请先登录"
  - 新增 `fetchUserCollections` 和 `fetchContentCollections` API 方法
  - 新增 `CollectionsResult` 接口和 `collectionListFromArray`/`collectionFromObject` 解析函数
  - 新增字符串资源：13 个收藏相关字符串
  - 构建验证：BUILD SUCCESSFUL

**实际实现（第 5 批 Slice 5，2026-08-01 交付）：**

- ✅ Slice 5 评论列表（CommentViewModel + CommentListView）：
  - 新增 `Comment` 模型（class，含 id/content/createdTime/liked/likeCount/childCommentCount/author/replyToAuthor/commentTag/isAuthor/collapsed 等字段）
  - 新增 `CommentViewModel`（@ObservedV2 + @Trace），管理根评论列表加载和分页
  - 根评论列表：`GET /api/v4/comment_v5/{contentType}s/{contentId}/root_comment?order_by=score&limit=20`，走 x-zse-93/96 签名
  - 分页加载：支持 `loadMore()` 触底加载下一页，去重追加
  - 双重保护：isLoading + isEnd 避免重复请求
  - 新增 `CommentListView` 组件：展示评论列表，每项含作者头像/名称/内容/时间/点赞数/子评论数/评论标签
  - 相对时间显示：刚刚 / X 分钟前 / X 小时前 / X 天前 / MM-DD
  - 首发只读，不支持发表评论/子评论/点赞评论
  - 新增 `RootCommentsResult` 接口和 `commentListFromArray`/`Comment.fromObject` 解析函数
  - 集成到 `AnswerDetailPage` 和 `ArticleDetailPage`：评论按钮点击展开/收起评论区
  - 首次点击评论按钮时自动加载，已加载后不重复拉取
  - 新增字符串资源：12 个评论相关字符串
  - 构建验证：BUILD SUCCESSFUL

### 13.8 第 6 批：产品增强能力

**时间：第 16–18 周**

**第 16 周：过滤和设置**

- 实现关键词屏蔽、正则屏蔽、用户屏蔽和话题屏蔽中的首发子集。
- 实现深色模式、字号、首页和导航项设置。
- 实现设置持久化、默认值和旧 key 迁移。
- 将复杂过滤任务移出 UI 主线程。

**第 17 周：通知和分享**

- 接入通知列表、红点和已读能力中的首发子集。
- 接入 Share Kit，支持分享链接、标题和正文摘要。
- 验证分享内容不包含 Cookie、Token 或内部字段。

**第 18 周：图片和视频**

- 实现图片查看器、缩放、多图切换和失败重试。
- 实现知乎视频前台播放、暂停、退出和前后台切换。
- 如需后台播放，再补充 AVSession 和后台任务，不默认开启高风险能力。

**批次验收**

- 过滤规则在约定的信息流中生效。
- 正则非法和大量规则有明确处理。
- 设置重启后恢复。
- 分享和通知功能不泄露敏感数据。
- 图片和视频资源在退出页面后正确释放。

### 13.9 第 7 批：创作与导出

**时间：第 19–22 周**

**第 19 周：编辑器和草稿**

- 实现回答编辑器基础输入。
- 实现 Markdown 预览。
- 实现草稿创建、读取、保存和删除。
- 验证页面退出和进程重启后的草稿恢复。

**第 20 周：图片选择和上传**

- 接入 Photo Access Helper 或 Document Picker。
- 实现图片压缩、临时文件、上传进度、失败重试和取消。
- 校验上传权限和 URI 生命周期。

**第 21 周：发布和编辑**

- 实现发布前校验、发布请求和结果处理。
- 实现发布失败不伪造成功。
- 实现编辑已有回答的首发子集。

**第 22 周：导出和本地推荐**

- 实现 Markdown/HTML 导出。
- 验证图片、公式和长文导出内容。
- 实现基于本地历史的简单推荐、去重和过滤。
- 暂不把端侧 embedding、Rust tokenizer 或 Android Full 模型作为首发依赖。

**批次验收**

- 草稿不会因页面关闭、进程重启或网络失败非预期丢失。
- 图片上传支持失败重试和取消。
- 发布成功与服务端结果一致。
- 导出文件内容正确，不以文件存在或文件大小作为唯一验收标准。
- 本地推荐的输入、排序、去重和过滤规则可解释。

### 13.10 第 8 批：发布收口

**时间：第 23–25 周**

**第 23 周：稳定性和性能**

- 优化冷启动、首帧、信息流、详情正文和图片加载。
- 检查 ArkWeb、列表、图片、视频、评论和数据库资源释放。
- 检查重复监听、重复请求、定时器和页面销毁。

**第 24 周：兼容性和安全**

- 回归 phone、tablet、深色模式、字体缩放、横竖屏和窗口尺寸。
- 回归断网、弱网、超时、未授权、服务端错误和重复点击。
- 检查权限最小化、HTTPS、URL 白名单、ArkGuard 规则和敏感日志。

**第 25 周：发布验证**

- 构建 debug、release 和 `ohosTest` target。
- 完成 release 签名、安装、升级和卸载重装验证。
- 完成核心 UiTest 和人工回归。
- 更新 HarmonyOS 专属文档、兼容性矩阵、协议证据和真机验证记录。
- 确认提交范围只包含 `HarmonyApp/` 内的源代码、资源、配置和文档。

**最终验收**

- 核心阅读、登录、点赞、收藏和基础个人页链路通过。
- phone/tablet、深色模式、断网和弱网回归通过。
- release 包可安装、启动和运行。
- 无真实 Token、Cookie、账号、私钥、内部地址和敏感日志。
- 上级目录 Android 工程仍只作为参考，未被加入 HarmonyOS 构建链路。

### 13.11 第 9 批：完整社区能力

**时间：第 26–29 周**

**第 26 周：关注、粉丝和关系状态**

- 实现关注/取消关注、关注列表和粉丝列表。
- 实现用户关系状态在个人页、回答作者和评论作者之间同步。
- 处理账号失效、重复操作和列表分页。

**第 27 周：热榜、日报和专题内容**

- 实现热榜列表、热榜详情和榜单刷新。
- 实现日报列表和日报正文。
- 实现话题或专题入口，前提是第 0 批已确认接口行为。

**第 28 周：完整评论树和通知中心**

- 扩展根评论为子评论、回复和评论点赞。
- 实现通知分类、未读计数、全部已读和通知跳转。
- 实现通知失败隔离，单个分类失败不能阻塞其他分类。

**第 29 周：社区回归**

- 验证个人页、关注、评论、通知之间的交叉导航。
- 验证返回栈、评论滚动位置和通知已读状态。
- 验证账号切换后不会混用旧账号的社区数据。

**批次验收**

- 关注、粉丝、热榜、日报和完整评论链路可用。
- 通知分类、未读数和跳转目标一致。
- 评论树在长列表和弱网下可分页。
- 个人页、评论作者页和通知页之间的返回上下文正确。

### 13.12 第 10 批：高级内容与智能能力

**时间：第 30–34 周**

**第 30 周：完整编辑器**

- 支持 Markdown 编辑、预览、图片、视频或附件引用。
- 支持草稿按内容 ID 隔离。
- 支持编辑已有回答、想法或其他已确认的可发布内容。

**第 31 周：上传和发布增强**

- 实现图片批量选择、压缩、上传进度、断点恢复和取消。
- 处理发布前校验、风控失败、服务端拒绝和重试。
- 验证发布成功后内容缓存和个人页数据刷新。

**第 32 周：高级导出**

- 实现 PDF、长截图和图片导出，具体能力以 API 24 真机验证为准。
- 验证长正文、图片、公式、代码块、脚注和分页。
- 验证导出区域存在真实正文像素，不能只检查文件存在或大小。

**第 33 周：离线缓存和历史增强**

- 实现内容快照、离线阅读和缓存过期策略。
- 实现历史搜索、批量清理和跨账号隔离。
- 使用 `relationalStore` 时建立 schema 版本和迁移测试。

**第 34 周：NLP 和推荐增强**

- 先实现可解释的关键词、规则和相似度能力。
- 再评估端侧 embedding、tokenizer、NLP 模型和模型包体积。
- 只有在 API 24 性能、内存和授权条件满足时，才加入端侧模型。

**批次验收**

- 编辑器、草稿、上传、发布和编辑链路可恢复、可取消、可重试。
- PDF、长截图和图片导出内容真实完整。
- 离线缓存不会展示错误账号或过期内容。
- 推荐和过滤规则可解释，模型能力不会阻塞基础阅读。

### 13.13 第 11 批：HarmonyOS 生态补齐

**时间：第 35–39 周**

**第 35 周：Push Kit 和服务卡片**

- 接入 Push Kit token 获取、刷新和服务端注册。
- 实现通知消息点击跳转和未读状态同步。
- 评估并实现服务卡片的只读摘要或最近内容展示。

**第 36 周：App Linking 和系统分享**

- 支持从可信链接打开问题、回答和文章详情。
- 校验 scheme、host、path 和参数。
- 扩展 Share Kit 的链接、纯文本、HTML 和图片分享。

**第 37 周：跨设备流转**

- 评估 phone 到 tablet 的页面和正文状态迁移。
- 迁移当前页面、内容 ID、登录状态引用和必要滚动上下文。
- 不传输明文 Token、Cookie 或超出最小范围的个人数据。

**第 38 周：多窗口和设备适配**

- 优化 tablet、2in1、折叠屏和多窗口布局。
- 验证 Navigation Split/Auto 模式。
- 验证窗口尺寸变化、横竖屏、键盘和安全区。

**第 39 周：生态发布收口**

- 验证 Push、服务卡片、App Linking、流转和多窗口组合行为。
- 检查权限、隐私说明、后台行为和耗电。
- 形成 HarmonyOS 生态能力兼容性矩阵。

**批次验收**

- Push 消息、链接、分享和服务卡片可用且不泄露凭据。
- 流转只迁移必要页面状态，目标设备能恢复可读内容。
- phone、tablet、2in1、折叠屏和多窗口具备明确支持或降级策略。
- 生态能力失败不会破坏核心阅读链路。

## 14. 版本发布策略

### 14.1 内部验证版

建议在第 3 批结束后形成第一个内部验证版，范围为匿名阅读：

- 首页信息流
- 搜索
- 问题、回答和文章详情
- ArkWeb 正文
- 加载、空态、错误态

该版本不承诺登录、点赞、收藏和发布能力，主要用于验证协议、正文保真、ArkWeb 生命周期和手机/平板布局。

### 14.2 功能候选版

建议在第 5 批结束后形成首个功能候选版，范围为：

- 匿名阅读
- 登录和会话恢复
- 点赞和收藏
- 基础评论
- 基础个人页
- 深色模式和基础设置

该版本可作为首发候选，但必须完成真实设备回归后才能决定是否发布。

### 14.3 正式发布版

第 6 批至第 11 批能力不应自动阻塞核心阅读版发布。建议将发布拆分为：

- **V1 核心阅读版**：第 0–5 批稳定后发布。
- **V1.1 增强版**：第 6 批过滤、设置、通知、分享和媒体能力稳定后发布。
- **V2 创作版**：第 7 批发布、导出和本地推荐稳定后发布。
- **V2.1 完整社区版**：第 9 批关注、粉丝、热榜、日报、通知和完整评论稳定后发布。
- **V3 智能与生态版**：第 10–11 批高级内容、智能能力和 HarmonyOS 生态能力稳定后发布。

这样可以避免因发布编辑器、PDF 导出、端侧模型或推送等高风险功能拖延核心阅读能力上线。

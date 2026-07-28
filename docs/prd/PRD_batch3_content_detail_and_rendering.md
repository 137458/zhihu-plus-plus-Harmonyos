# PRD：第 3 批 - 内容详情与正文渲染

## Problem Statement

作为知乎++HarmonyOS 移植用户，第 2 批完成后我能在首页浏览推荐信息流和搜索内容，但点击任何卡片只能进入占位页（仅显示标题栏和返回按钮），无法查看问题详情、回答正文、文章内容。我需要一个完整的阅读链路：从首页/搜索结果点击卡片 → 进入对应详情页 → 浏览标题、作者、统计信息和正文（含图片、表格、公式、代码块、链接）。当前正文渲染能力为空，`web/` 目录只有 README。

## Solution

实现问题、回答、文章三类详情页的端到端阅读切片，覆盖接口请求、模型解析、ViewModel 状态管理、ArkWeb 正文容器和详情页 UI。正文首版采用 ArkWeb 承载知乎 `content` 字段的 HTML（移植计划第 7 节已定），不重写 Markdown/LaTeX 渲染器。复用第 2 批已建立的 `NetworkClient`/`ZseSigner`/`CookieJar`/`ApiError`/`Author`/`Paging`/`StateView` 基础设施，新增详情专用模型、接口、ViewModel 和 ArkWeb 容器组件。

## User Stories

1. 作为匿名用户，我希望点击首页回答卡片能进入回答详情页，查看完整回答正文
2. 作为匿名用户，我希望点击首页文章卡片能进入文章详情页，查看完整文章正文
3. 作为匿名用户，我希望点击首页问题卡片能进入问题详情页，查看问题标题、描述和回答列表
4. 作为匿名用户，我希望在问题详情页点击某条回答能进入回答详情页
5. 作为匿名用户，我希望详情页加载时看到加载指示器，而不是空白
6. 作为匿名用户，我希望详情页加载失败时看到错误提示和重试按钮
7. 作为匿名用户，我希望详情页正文为空时看到友好的空状态提示
8. 作为匿名用户，我希望详情页顶部立即显示预览标题（来自路由参数），避免请求未返回时空白
9. 作为匿名用户，我希望正文可滚动，支持图片、表格、代码块、引用和链接展示
10. 作为匿名用户，我希望正文中的图片能正常加载（处理知乎防盗链）
11. 作为匿名用户，我希望正文中的 LaTeX 公式能渲染（首版可降级为图片或源码）
12. 作为匿名用户，我希望正文中的外链点击被拦截或提示，不会直接跳转到不可信主机
13. 作为匿名用户，我希望从详情页返回时回到来源页（首页或搜索页），且来源页滚动位置保留
14. 作为匿名用户，我希望短时间内重复进入同一详情页时使用缓存，避免无意义重复请求
15. 作为匿名用户，我希望在问题详情页看到回答数、浏览数、评论数、关注数等统计信息
16. 作为匿名用户，我希望在问题详情页看到问题描述（detail 字段的 HTML）
17. 作为匿名用户，我希望在回答/文章详情页看到作者头像、姓名、简介
18. 作为匿名用户，我希望在回答/文章详情页看到点赞数和评论数
19. 作为匿名用户，我希望在回答详情页看到所属问题标题，并可点击返回问题详情
20. 作为匿名用户，我希望问题详情页的回答列表支持分页加载更多
21. 作为匿名用户，我希望问题详情页的回答列表支持下拉刷新
22. 作为匿名用户，我希望深色模式下正文可读（背景色、文字色、代码块色适配）
23. 作为匿名用户，我希望平板上正文宽度合理，不会撑满整个屏幕
24. 作为匿名用户，我希望正文加载超时时有明确反馈，不是无限等待
25. 作为匿名用户，我希望接口返回风控页或异常结构时看到"内容不可用"提示
26. 作为匿名用户，我希望详情页 ArkWeb 容器销毁后不残留监听器或定时器
27. 作为开发者，我希望详情接口的 URL、include 参数和签名头与 Android 参考实现一致
28. 作为开发者，我希望所有详情模型使用显式 ArkTS 类型，便于静态检查
29. 作为开发者，我希望详情解析失败的单字段跳过，不影响其他字段展示
30. 作为开发者，我希望详情缓存有 TTL 过期机制，避免展示过期内容
31. 作为开发者，我希望 ArkWeb 容器只加载 HTTPS 和可信主机，外链跳转必须校验
32. 作为开发者，我希望 ArkWeb 不把 Token/Cookie/个人信息拼接到正文 HTML
33. 作为开发者，我希望 ArkWeb 桥接最小化，只暴露必要的事件回调
34. 作为开发者，我希望正文 HTML 在加载前经过协议层转换（注入深色模式 CSS、图片 Referer 处理）
35. 作为开发者，我希望详情页 ViewModel 复用第 2 批的空错载状态管理
36. 作为开发者，我希望卡片点击预留的路由参数（QuestionDetailParams 等）被正确消费
37. 作为开发者，我希望首页和搜索页的卡片点击回调接入真实路由跳转
38. 作为开发者，我希望问题回答列表复用 FeedCard 模型和 FeedCardDataSource

## Implementation Decisions

### 模块划分

- **`api/ZhihuApi.ets`（扩展）**：
  - 新增 `fetchQuestionDetail(questionId): Promise<QuestionDetail>`
  - 新增 `fetchQuestionAnswers(questionId, pagingNext?, order?): Promise<QuestionAnswersResult>`（回答列表分页）
  - 新增 `fetchAnswerDetail(answerId): Promise<AnswerDetail>`
  - 新增 `fetchArticleDetail(articleId): Promise<ArticleDetail>`
  - 内部组装 zse 签名头、Cookie、include 参数、Web UA、`x-requested-with: fetch`
  - 复用第 2 批的 `parseXxxResponse` 风格（风控判定 + 逐字段解析）

- **`model/`（新增）**：
  - `QuestionDetail.ets`：`class QuestionDetail { id: string; title: string; detail: string; excerpt: string; answerCount: number; visitCount: number; commentCount: number; followerCount: number; voteupCount: number; author: Author; topics: Topic[]; }`
  - `AnswerDetail.ets`：`class AnswerDetail { id: string; content: string; excerpt: string; voteupCount: number; commentCount: number; thanksCount: number; author: Author; question: AnswerDetailQuestion; ipInfo: string; createdTime: number; updatedTime: number; }`
  - `ArticleDetail.ets`：`class ArticleDetail { id: string; title: string; content: string; excerpt: string; voteupCount: number; commentCount: number; author: Author; topics: Topic[]; ipInfo: string; created: number; updated: number; }`
  - `Topic.ets`：`class Topic { id: string; name: string; avatarUrl?: string; }`
  - `AnswerDetailQuestion.ets`（或内联）：`class AnswerDetailQuestion { id: string; title: string; }`

- **`viewmodel/`（新增）**：
  - `QuestionDetailViewModel.ets`：管理问题详情 + 回答列表分页，持有 `detail: QuestionDetail | null` 和回答列表（复用 `BasePaginationViewModel<FeedCard>` 或独立维护）
  - `AnswerDetailViewModel.ets`：管理回答详情加载、缓存命中判断
  - `ArticleDetailViewModel.ets`：管理文章详情加载、缓存命中判断
  - `ContentDetailCache.ets`：详情缓存，内存 Map + TTL（10 分钟，参考 Android LRU 容量 100），key = `contentType + '_' + contentId`

- **`web/ArticleWebContainer.ets`（新增）**：
  - ArkWeb `Web` 组件封装，接收 `htmlContent`、`onPageFinish`、`onError`、`onDestroy` 回调
  - 内部将知乎 `content` HTML 包装为完整 HTML 文档（注入深色/浅色 CSS、图片 Referer meta、KaTeX 占位）
  - 配置 HTTPS only、可信主机白名单（`www.zhihu.com`、`pic1-4.zhimg.com`、`picx/pica/picb/picd.zhimg.com`、`equation?tex`）
  - 外链点击拦截：`onControllerAttached` 中注册 `runJavaScript` 钩子，或通过 `WebControllerClient.onLoadIntercept` 校验 URL
  - 最小化 JS 桥接：仅暴露图片点击、链接点击事件回调给原生
  - 生命周期：`onPageBegin`/`onPageFinish`/`onErrorReceive`/`onDestroy` 清理

- **`pages/`（改造）**：
  - `QuestionDetailPage.ets`：从占位页改造为真实页面，顶部问题标题/统计/描述 + 下方回答列表（LazyForEach）
  - `AnswerDetailPage.ets`：从占位页改造为真实页面，顶部作者卡 + ArkWeb 正文 + 统计栏
  - `ArticleDetailPage.ets`：从占位页改造为真实页面，顶部作者卡 + ArkWeb 正文 + 统计栏
  - 三个页面均使用 `HdsNavigation + HdsNavigationTitleMode.MINI + ScrollEffectType.GRADIENT_BLUR`（HDS 规范）

- **`pages/HomePage.ets` + `pages/SearchPage.ets`（改造）**：
  - 卡片点击回调接入 `navPathStack.pushPathByName`，根据 `contentType` 分发到 QUESTION_DETAIL/ANSWER_DETAIL/ARTICLE_DETAIL
  - 移除第 1 批的测试入口按钮（`home_test_push`）或保留为调试开关

### 关键技术决策

- **正文渲染方式**：首版用 ArkWeb 承载知乎 `content` 字段的 HTML（移植计划第 7 节已定）。Android 端虽用自研 Compose Markdown 渲染器，但 HarmonyOS 首版优先内容保真，原生渲染器留待后续批次。
- **接口 URL 与 include**：逐字采用证据表 `03-content-detail.md` §3 的值，不臆造字段：
  - 问题详情：`GET https://www.zhihu.com/api/v4/questions/{id}?include=read_count,visit_count,answer_count,voteup_count,comment_count,follower_count,detail,excerpt,author,relationship.is_following,topics`
  - 回答详情：`GET https://www.zhihu.com/api/v4/answers/{id}?include=.settings,content,editable_content,paid_info,can_comment,excerpt,thanks_count,voteup_count,comment_count,visited_count,attachment,reaction,ip_info,pagination_info,endorsements,question.topics,question.author,reaction.relation.voting,author.badge_v2,settings.table_of_contents.enabled`
  - 文章详情：`GET https://www.zhihu.com/api/v4/articles/{id}?include=content,topics,paid_info,can_comment,excerpt,thanks_count,voteup_count,comment_count,visited_count,relationship,ip_info,relationship.vote,author.badge_v2`
  - 问题回答列表：`GET https://www.zhihu.com/api/v4/questions/{id}/feeds?limit=20&order=default`，include 默认 `data[*].content,excerpt,headline,target.author.badge_v2`
- **请求头**：复用第 2 批 `createZse96Header`；新增 `User-Agent`（Web UA：`Mozilla/5.0 (X11; U; Linux x86_64; en-US) AppleWebKit/540.0 (KHTML, like Gecko) Ubuntu/10.10 Chrome/9.1.0.0 Safari/540.0`）和 `x-requested-with: fetch`（证据 03 §3）
- **匿名访问**：问题/回答/文章详情接口均 `allowGuestAccess=true`（证据 03 §2 行为表"未登录也可读"），无 `d_c0` 时跳过签名
- **风控判定**：复用第 2 批规则，响应非 JsonObject 或缺关键字段抛 `ApiError.riskControl`
- **缓存策略**：内存 Map + TTL 10 分钟（参考 Android `ContentDetailCache` LRU 容量 100、TTL 10 分钟）；key = `contentType + '_' + contentId`；返回后命中且未过期直接用缓存，下拉刷新强制跳过缓存
- **图片防盗链**：知乎图片 CDN 需 Referer，ArkWeb 中通过 `<meta name="referer" content="always">` 或在 HTML 中注入 `<base>` 处理；原生 `Image` 组件配置 `headers`
- **LaTeX 公式**：首版不下载 KaTeX 字体（Android 用自研渲染），知乎 HTML 中公式以 `<img eeimg="1" src="https://www.zhihu.com/equation?tex={URL_ENCODED}">` 形式存在，ArkWeb 直接加载该图片即可
- **深色模式**：ArkWeb HTML 中注入 CSS 变量，根据 `ConfigurationConstant.ColorMode` 切换 `--bg-color`/`--text-color`/`--code-bg` 等
- **回答列表分页**：复用 `BasePaginationViewModel<FeedCard>` + `FeedCardDataSource`，问题 feeds 响应结构与首页推荐一致（`data[]` + `paging`）
- **状态管理**：ViewModel 使用 `@ObservedV2 + @Trace`，UI 通过 `@ComponentV2 + @Local` 订阅
- **HDS 规范**：三个详情页使用 `HdsNavigation + HdsNavigationTitleMode.MINI + ScrollEffectType.GRADIENT_BLUR + systemMaterialEffect(IMMERSIVE)`（模式三混合写法，与 PlaceholderPage 一致）
- **路由参数消费**：详情页 `onReady` 中读取 `ctx.pathInfo.param`，传入 ViewModel 加载

### API 契约

- `ZhihuApi.fetchQuestionDetail(questionId: string): Promise<QuestionDetail>`
- `ZhihuApi.fetchQuestionAnswers(questionId: string, pagingNext?: string, order?: string): Promise<QuestionAnswersResult>`，`QuestionAnswersResult { items: FeedCard[]; paging: Paging | null; }`
- `ZhihuApi.fetchAnswerDetail(answerId: string): Promise<AnswerDetail>`
- `ZhihuApi.fetchArticleDetail(articleId: string): Promise<ArticleDetail>`
- `ContentDetailCache.get<T>(key: string): T | null`
- `ContentDetailCache.put<T>(key: string, value: T): void`
- `QuestionDetailViewModel.load(questionId: string, previewTitle?: string): Promise<void>`
- `AnswerDetailViewModel.load(answerId: string): Promise<void>`
- `ArticleDetailViewModel.load(articleId: string): Promise<void>`

## Testing Decisions

### 测试原则

- **只测外部行为**：测试 ViewModel/API/Model 的公共方法输出，不测私有方法
- **优先复用现有测试目录**：`entry/src/ohosTest/ets/test/`（设备端单元测试 + UI 测试）
- **使用脱敏响应样本**：所有测试用例使用脱敏 JSON 响应样本，不含真实 Cookie/Token/账号
- **seams 确认**：与用户确认沿用第 2 批模式，新增 `ContentDetail.test.ets` 单元 seam + 扩展 `Ability.test.ets` UI seam

### 测试范围

| 模块 | 测试类型 | 测试内容 |
|------|---------|---------|
| `model/QuestionDetail.ets` | 设备单元测试 | fromObject 解析：完整字段、缺字段、风控响应、author/topics 解析 |
| `model/AnswerDetail.ets` | 设备单元测试 | fromObject 解析：content/excerpt/author/question/统计字段 |
| `model/ArticleDetail.ets` | 设备单元测试 | fromObject 解析：title/content/author/topics/统计字段 |
| `api/ZhihuApi.ets`（详情方法） | 设备单元测试 | URL 构造、include 参数、headers 组装、风控响应识别、分页 next 传递 |
| `viewmodel/QuestionDetailViewModel.ets` | 设备单元测试 | load 成功/失败/缓存命中、回答列表分页累加、下拉刷新清空重拉 |
| `viewmodel/AnswerDetailViewModel.ets` | 设备单元测试 | load 成功/失败/缓存命中、previewTitle 立即展示 |
| `viewmodel/ArticleDetailViewModel.ets` | 设备单元测试 | load 成功/失败/缓存命中 |
| `web/ArticleWebContainer.ets` | UI 测试 | ArkWeb 容器可见性、加载完成回调、外链拦截 |
| `pages/QuestionDetailPage.ets` | UI 测试 | 卡片点击→进入详情、标题/统计/回答列表可见、返回回到首页 |
| `pages/AnswerDetailPage.ets` | UI 测试 | 进入回答详情、作者卡/正文可见、返回 |
| `pages/ArticleDetailPage.ets` | UI 测试 | 进入文章详情、作者卡/正文可见、返回 |
| `pages/HomePage.ets`（卡片点击） | UI 测试 | 卡片点击触发正确路由跳转 |

### 测试数据

- 脱敏 JSON 样本放在 `entry/src/ohosTest/ets/test/resources/` 或 `docs/evidence/samples/content-detail/`（证据 03 §7 建议）
- 至少覆盖：`question_detail.json`、`question_feeds_default.json`、`answer_detail.json`、`article_detail.json`、空列表边界、风控响应

## Out of Scope

- **回答切换导航**：Android 的 `QuestionAnswerNavigator`（上一题/下一题/预取/续链/`PaginationInfoNavigator`）不纳入第 3 批，留给后续批次
- **登录态互动**：点赞、收藏、评论、关注、举报需登录，第 5 批实现
- **评论列表**：第 5 批实现
- **AI 总结**：第 10 批实现
- **内容导出**（HTML/图片/Markdown）：第 7 批实现
- **段评/划线**（segmentInfos）：高级功能，后续批次
- **原生 Markdown 渲染器**：首版用 ArkWeb，原生渲染器留待后续批次
- **KaTeX 字体下载与原生 LaTeX 渲染**：首版用知乎 equation 图片，原生渲染留待后续
- **视频盒子**（`<a class="video-box">`）：首版降级为普通链接
- **脚注跳转**：首版不实现跳转交互，仅展示
- **关注问题**：第 5 批实现
- **浏览上报（touch/read）**：后续批次
- **网络变化实时监听**：第 4 批 EntryAbility 接入
- **深链接（AppLinking）跳转**：第 4 批接入

## Further Notes

- **ArkWeb 首版策略**：移植计划第 7 节明确"首版不重写完整 Markdown/LaTeX 渲染器，采用 ArkWeb 承载已经在 Android 侧验证过的 HTML、CSS 和 KaTeX 资产"。Android 端虽用自研 Compose 渲染器（证据 03 §6.1），但 HarmonyOS 首版优先内容保真，原生渲染器留待后续批次优化性能。
- **缓存 TTL**：参考 Android `ContentDetailCache`（LRU 容量 100、TTL 10 分钟），HarmonyOS 首版用简单 Map + 时间戳，不引入 LRU 复杂度，容量超限时清空最早条目。
- **安全要求**（移植计划 §7.3）：
  - 只允许 HTTPS 和明确可信的主机列表
  - 不允许正文内容直接执行不受控的原生方法
  - 不把 Token、Cookie 或个人信息拼接到正文 HTML
  - 外链跳转必须校验协议、主机和路径
  - ArkWeb 销毁后必须无残留监听器、定时器或页面引用
- **图片防盗链**：知乎图片 CDN 有 Referer 防盗链，ArkWeb 中通过 `<meta name="referer" content="always">` 或在 HTML 中注入 `<base href="https://www.zhihu.com/">` 处理。
- **Web UA**：详情接口需 Web UA（`Mozilla/5.0 (X11; U; Linux x86_64; en-US) AppleWebKit/540.0...`），与 Android 端 `DEFAULT_ZHIHU_USER_AGENT` 一致（证据 03 §3）。第 2 批首页/搜索接口未显式设置 UA，第 3 批详情接口必须设置。
- **回答列表 feeds**：问题详情响应不直接包含回答列表（证据 03 §3），需单独请求 `/api/v4/questions/{id}/feeds`。响应结构与首页推荐类似（`data[]` + `paging`），可复用 `FeedCard.fromObject` 解析。
- **main_pages.json**：三个详情页已注册（第 1 批占位页），无需新增路由。
- **路由参数已就绪**：`QuestionDetailParams`/`AnswerDetailParams`/`ArticleDetailParams` 已在第 1 批定义（`AppRouter.ets`），第 3 批消费即可。

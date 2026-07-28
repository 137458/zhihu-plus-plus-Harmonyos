# PRD：第 2 批 - 匿名信息流与搜索

## Problem Statement

作为知乎++HarmonyOS 移植用户，我希望在**未登录**状态下能够浏览首页推荐信息流、点击卡片进入内容详情（第 3 批实现），并能通过搜索查找内容。当前第 1 批只完成了主壳和占位页面，没有真实网络请求、数据模型和列表渲染能力，用户看到的是空白占位页。

## Solution

实现端到端的匿名阅读纵向切片：从 `@kit.NetworkKit` HTTP 客户端到首页推荐卡片渲染、搜索框输入与结果列表展示。默认采用 Web 端算法（`https://api.zhihu.com/topstory/recommend` + zse 签名），支持匿名访问（`allowGuestAccess=true`）。搜索接口 `https://www.zhihu.com/api/v4/search_v3` 要求登录，未登录时搜索入口引导登录（第 4 批实现完整登录，本批仅 UI 阻断）。

## User Stories

1. 作为匿名用户，我希望打开应用后首页自动加载推荐信息流，以便快速浏览热门内容
2. 作为匿名用户，我希望下拉刷新首页信息流，以获取最新推荐内容
3. 作为匿名用户，我希望滚动到底部时自动加载下一页推荐内容，避免手动翻页
4. 作为匿名用户，我希望首页加载失败时看到错误提示和重试按钮，而不是空白页
5. 作为匿名用户，我希望首页加载中看到骨架屏或加载指示器，而不是突兀的空白
6. 作为匿名用户，我希望首页空数据时看到友好的空状态提示
7. 作为匿名用户，我希望看到每张卡片包含标题、作者、摘要、缩略图、点赞数和评论数
8. 作为匿名用户，我希望点击卡片能跳转到对应内容详情页（第 3 批实现，本批预留路由参数）
9. 作为用户，我希望进入搜索页能输入关键词并提交搜索
10. 作为用户，我希望看到搜索结果列表，每项包含标题、摘要、作者、类型标识
11. 作为用户，我希望搜索结果支持分页加载更多
12. 作为用户，我希望在搜索页看到热搜榜单，点击热搜词直接搜索
13. 作为用户，我希望搜索历史保存在本地，点击历史词快速搜索
14. 作为用户，我希望清空搜索历史
15. 作为用户，我希望搜索时输入为空时无法提交，避免无效请求
16. 作为用户，我希望搜索失败时看到错误反馈和重试入口
17. 作为用户，我希望网络断开时首页和搜索都能给出明确的断网提示
18. 作为用户，我希望网络请求超时时有合理的超时反馈，而不是无限等待
19. 作为用户，我希望接口返回异常结构（风控页、HTML 响应）时看到"被风控"的友好提示
20. 作为开发者，我希望网络层统一处理 zse 签名、Cookie 管理、超时和错误转换，UI 层只关心业务状态
21. 作为开发者，我希望所有领域模型使用显式 ArkTS 类型，便于静态检查和重构
22. 作为开发者，我希望接口解析失败时跳过该条目而非整批失败，保证可用数据正常展示
23. 作为开发者，我希望相同脱敏响应的解析结果与 Android 参考实现一致
24. 作为开发者，我希望网络请求资源（HttpRequest）在完成或异常时被正确释放，避免内存泄漏
25. 作为开发者，我希望分页加载有重复请求保护，避免快速滚动触发多次请求
26. 作为开发者，我希望卡片列表使用稳定唯一 key，避免 LazyForEach 错位

## Implementation Decisions

### 模块划分

- **`api/`**：
  - `NetworkClient.ets`：基于 `@kit.NetworkKit` 的 `http` 模块封装的统一 HTTP 客户端，提供 `get<T>(url, headers, timeout): Promise<HttpResponse<T>>`，内部处理 `connectTimeout`、`readTimeout`、`HttpRequest.destroy()` 资源释放、HTTP 状态码到业务错误枚举的转换
  - `ZseSigner.ets`：知乎 Web 签名实现，复现 `x-zse-96: 2.0_ + ZseSigner.encryptZseV4(md5Hex(zse93 + "+" + pathname + "+" + dc0 + "+" + body))` 算法（参考 01 证据 §4.2，ZB S-Box 和 ZK 轮密钥常量见证据表）
  - `ZhihuApi.ets`：知乎 API 封装层，提供 `fetchHomeRecommend(pagingNext?: string)`、`search(query, filters)`、`fetchHotSearch()` 等方法，内部组装 zse 签名头、Cookie、include 参数
  - `CookieJar.ets`：Cookie 管理器，第 2 批只管理匿名 `d_c0`（从响应 Set-Cookie 提取，存内存），登录态 Cookie 第 4 批接入

- **`model/`**：
  - `Paging.ets`：通用分页模型 `interface Paging { next: string; isEnd: boolean; previous?: string }`
  - `Author.ets`：作者模型 `class Author { id: string; urlToken: string; name: string; avatarUrl: string; headline?: string; }`
  - `FeedCard.ets`：首页卡片统一模型 `class FeedCard { stableKey: string; contentType: ContentType; title: string; excerpt: string; author: Author; thumbnail?: string; voteupCount: number; commentCount: number; rawId: string; }`，从 Feed.Target 多态响应解析为扁平 UI 模型
  - `ContentType.ets`：枚举 `enum ContentType { ANSWER, ARTICLE, QUESTION, PIN, ZVIDEO, UNKNOWN }`
  - `SearchResult.ets`：搜索结果模型 `class SearchResultItem { type: string; id: string; title: string; excerpt: string; author?: Author; highlight?: string; }`
  - `HotSearch.ets`：热搜模型 `class HotSearchItem { query: string; label: string; hotShow: number; }`
  - `ApiError.ets`：业务错误枚举 `enum ApiErrorCode { NETWORK_ERROR, TIMEOUT, PARSE_ERROR, RISK_CONTROL, UNAUTHORIZED, NOT_FOUND, SERVER_ERROR, UNKNOWN }` + `class ApiError { code: ApiErrorCode; message: string; cause?: Error }`

- **`viewmodel/`**：
  - `BasePaginationViewModel.ets`：抽象分页基类，维护 `items: T[]`、`isLoading: boolean`、`isPullToRefresh: boolean`、`errorMessage: string`、`paging: Paging | null`，提供 `loadMore()`、`pullToRefresh()` 抽象方法、`addItems(newItems, dedupeByKey)` 去重逻辑、`isLoading` 重复请求保护
  - `HomeFeedViewModel.ets`：首页 ViewModel，继承 `BasePaginationViewModel<FeedCard>`，实现 `loadMore` 调用 `ZhihuApi.fetchHomeRecommend(paging?.next)`，解析 Feed 数组为 `FeedCard[]`
  - `SearchViewModel.ets`：搜索 ViewModel，继承 `BasePaginationViewModel<SearchResultItem>`，额外维护 `query: string`、`hotSearchItems: HotSearchItem[]`、`searchHistory: string[]`（持久化到 preferences）

- **`pages/`**：
  - `HomePage.ets`：改造为 `List + LazyForEach` 渲染 `FeedCard`，支持下拉刷新（`Refresh` 组件）、触底加载更多（`onReachEnd`）、空/错/载状态切换
  - `SearchPage.ets`：搜索输入框（`TextInput`）+ 提交（`onSubmit` 回调）+ 热搜列表 + 历史列表 + 结果 `List + LazyForEach`
  - `components/FeedCardView.ets`：单卡片 UI 组件，展示标题/作者/摘要/缩略图/互动数
  - `components/SearchResultView.ets`：单条搜索结果 UI 组件
  - `components/HotSearchItemView.ets`：热搜条目 UI
  - `components/SearchHistoryItemView.ets`：历史条目 UI
  - `components/StateView.ets`：统一的空/错/载状态视图

### 关键技术决策

- **HTTP 库**：使用 `@kit.NetworkKit` 的 `http` 模块，不引入第三方库（遵守 api/README.md 约束）
- **签名实现**：zse96 算法参考 01 证据 §4.2 的 ZseSigner.kt 和 rs-zse-sign Rust 参考实现，ArkTS 版使用 `@kit.CryptoArchitectureKit` 的 md5 能力
- **匿名访问**：第 2 批只实现 Web 端算法匿名访问，`d_c0` 缺失时跳过签名（与 Android 行为一致，02 §3 通用说明）
- **风控判定**：响应非 JsonObject 或缺 `$.data` 字段抛 `ApiError(PARSE_ERROR, '风控')`（02 §3 风控判定规则）
- **搜索登录要求**：`allowGuestAccess=false`，未登录时搜索提交给出"请先登录"提示（第 4 批接入真实登录后移除）
- **资源释放**：每个 `http.HttpRequest` 在 `then`/`catch`/`finally` 中调用 `destroy()`，避免句柄泄漏
- **去重**：`addItems` 用 `stableKey` 集合去重，防止分页接口返回重复条目
- **图片加载**：使用 ArkUI `Image` 组件原生能力，配置占位图、失败图、`alt` 属性，不做复杂缓存（第 3 批接入 ImageKit）
- **分页保护**：`isLoading` 标志位 + `paging.isEnd` 双重判断，避免重复触发 `loadMore`
- **搜索历史**：使用 `@kit.ArkData` 的 `preferences` 模块持久化，key `searchHistoryQueries`，上限 20（与 Android 一致，02 §7）
- **状态管理**：ViewModel 使用 `@ObservedV2 + @Trace` 装饰器，UI 层通过 `@ComponentV2 + @Local` 订阅
- **网络变化监听**：第 2 批暂不实现网络变化实时监听（第 4 批 EntryAbility 接入），仅在请求失败时给出反馈

### API 契约

- `NetworkClient.get(url, headers?, timeout?): Promise<HttpResponse>`，`HttpResponse { statusCode: number; body: string; headers: Object }`
- `ZhihuApi.fetchHomeRecommend(pagingNext?: string): Promise<FeedCard[]>`
- `ZhihuApi.search(query: string, filters?: SearchFilters): Promise<SearchResultItem[]>`
- `ZhihuApi.fetchHotSearch(): Promise<HotSearchItem[]>`
- `BasePaginationViewModel.loadMore(): Promise<void>`
- `BasePaginationViewModel.pullToRefresh(): Promise<void>`

## Testing Decisions

### 测试原则

- **只测外部行为**：测试 ViewModel 和 API 的公共方法输出，不测内部私有方法
- **优先复用现有测试目录**：`entry/src/test/`（本地单元测试）和 `entry/src/ohosTest/`（UI 测试）
- **使用脱敏响应样本**：所有测试用例使用脱敏后的 JSON 响应样本，不含真实 Cookie/Token

### 测试范围

| 模块 | 测试类型 | 测试内容 |
|------|---------|---------|
| `model/` | 本地单元测试 | FeedCard/SearchResultItem/Paging 模型解析，使用脱敏 JSON 样本验证字段映射、空字段处理、类型转换 |
| `api/ZseSigner.ets` | 本地单元测试 | zse96 签名算法正确性，使用已知输入输出对验证（来自 01 证据 §4.2 测试用例） |
| `api/NetworkClient.ets` | 本地单元测试 | 超时、HTTP 错误码到 ApiError 映射、响应体解析失败、资源释放（mock HttpRequest） |
| `api/ZhihuApi.ets` | 本地单元测试 | URL 构造、headers 组装、分页 next 参数传递、风控响应识别 |
| `viewmodel/HomeFeedViewModel.ets` | 本地单元测试 | loadMore 累加、pullToRefresh 清空重拉、去重、isLoading 保护、isEnd 停止 |
| `viewmodel/SearchViewModel.ets` | 本地单元测试 | query 提交、分页、历史持久化、热搜加载 |
| `pages/HomePage.ets` | UI 测试 | 冷启动加载、下拉刷新、触底加载、空错载状态切换 |
| `pages/SearchPage.ets` | UI 测试 | 输入提交、热搜点击、历史点击、结果列表、登录阻断 |

### 测试数据

- 脱敏 JSON 响应样本放在 `entry/src/test/resources/feed_sample.json`、`search_sample.json`、`hot_search_sample.json`
- ZseSigner 测试向量来自 01 证据 §4.2 中的已知 input/output 对

## Out of Scope

- **登录态访问**：第 4 批实现登录接口、Cookie 持久化、Token 刷新
- **内容详情页渲染**：第 3 批实现 QuestionDetail/AnswerDetail/ArticleDetail 的完整渲染
- **图片高级缓存**：第 3 批接入 ImageKit，本批只用 Image 基础能力
- **关注动态 feed**：关注 tab 需要 `z_c0` 登录态，第 4 批接入
- **Android 端算法推荐**：第 2 批只实现 Web 端算法，Android 算法和混合模式后续批次
- **本地推荐引擎**：第 10 批实现
- **浏览上报（touch/read）**：需要 `d_c0` 匿名 Cookie，但上报失败静默处理，优先级低，本批暂不实现
- **网络变化实时监听**：第 4 批 EntryAbility 接入
- **深链接（AppLinking）跳转**：第 4 批接入

## Further Notes

- **匿名访问前提**：知乎 Web 端 API 默认允许 `allowGuestAccess=true`，但服务端可能要求 `d_c0` cookie 进行匿名标识。首次请求时从响应 `Set-Cookie` 提取 `d_c0`，后续请求自动携带。`d_c0` 缺失时 zse 签名跳过（02 §3 通用说明）。
- **风控风险**：匿名访问频率过高可能触发风控，本批不实现节流，后续批次根据实测调整。
- **签名算法风险**：zse96 算法依赖 `ZseSigner.encryptZseV4`，这是知乎自定义加密（ZB S-Box + ZK 轮密钥 + 自定义 Base64）。ArkTS 实现需要严格复现，建议参考 Rust 版 `rs-zse-sign/` 作为对照实现。
- **搜索登录要求**：02 证据 §3 明确 `allowGuestAccess=false`，未登录用户搜索会返回 401。本批 UI 层阻断（弹"请先登录"提示），不实际发起请求。
- **图片防盗链**：知乎图片 CDN 有 Referer 防盗链，ArkUI `Image` 组件需配置 `headers` 添加 Referer，或在 WebView 中加载。本批先用基础 Image，若图片加载失败显示失败图。
- **main_pages.json**：新增页面无需注册（已有 HomePage/SearchPage），但需确认路由参数传递。

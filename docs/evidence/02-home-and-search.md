# 首页推荐与搜索证据表

> 调研范围：`zhihu-plus-plus/` 下首页推荐与搜索相关源码及测试。所有结论均以源码/测试为据，无法确认的字段标注「待确认」。本表不含任何真实 Cookie/Token/账号。

## 1. 功能模块清单

| 模块 | Android 入口文件 | 简述 |
|---|---|---|
| 首页推荐（Web 端算法） | `shared/src/commonMain/.../viewmodel/feed/HomeFeedViewModel.kt` | 调用 `https://api.zhihu.com/topstory/recommend`（Web 端 JSON API，需 zse 签名），支持匿名访问，记录 touch/read 行为 |
| 首页推荐（Android 端算法） | `shared/src/commonMain/.../viewmodel/za/AndroidHomeFeedViewModel.kt` | 同 URL 但使用 Android UA + Android 专属 headers，无 zse 签名，解析 `ComponentCard` 卡片 |
| 首页推荐（混合） | `shared/src/commonMain/.../viewmodel/za/MixedHomeFeedViewModel.kt` | 并发执行 Android + Web 两个 fetch，结果合并入同一 `displayItems` |
| 首页推荐（本地） | `shared/src/commonMain/.../viewmodel/local/LocalHomeFeedViewModel.kt` | 不走网络，依赖 `LocalRecommendationEngine`（第 10 批移植） |
| Feed 分页基类 | `shared/src/commonMain/.../viewmodel/feed/BaseFeedViewModel.kt` | 维护 `displayItems`/`latestLoadedDisplayItems`/`isPullToRefresh`，提供 `pullToRefresh`、`addDisplayItems` 去重 |
| 分页框架 | `shared/src/commonMain/.../viewmodel/PaginationViewModel.kt` | 通用 `PaginationViewModel<T>`，处理 `lastPaging.next` 翻页、`isEnd`、`include` 字段、zse 签名 fetch、401 token 刷新、解码失败日志 |
| 推荐模式枚举 | `shared/src/commonMain/.../shared/data/RecommendationMode.kt` | WEB/ANDROID/LOCAL/MIXED 四种，持久化 key 为 `server`/`android`/`local`/`mixed` |
| Feed 数据模型 | `shared/src/commonMain/.../shared/data/Feed.kt` | `Feed` sealed interface（7 个子类型）+ `Feed.Target` sealed interface（5 个子类型），全部 JSON 序列化 |
| SegmentInfo 模型 | `shared/src/commonMain/.../shared/data/SegmentInfo.kt` | 段评/段赞元数据，含 `BooleanCompatSerializer`（兼容 bool/int/string） |
| 搜索 ViewModel | `shared/src/commonMain/.../viewmodel/feed/SearchViewModel.kt` | 调用 `https://www.zhihu.com/api/v4/search_v3`，支持排序/类型/时间过滤，支持用户创作限定搜索 |
| 搜索结果模型 | `shared/src/commonMain/.../shared/data/SearchResult.kt` | `search_result`/`koc_box`/`knowledge_ad` 三种 object 类型，自定义多态反序列化 |
| 热搜 | `shared/src/commonMain/.../ui/SearchScreen.kt`（内 `fetchHotSearch`） | 调用 `https://www.zhihu.com/api/v4/search/hot_search`，取前 15 条 |
| 搜索历史 | `shared/src/commonMain/.../ui/SearchScreen.kt` | SharedPreferences `searchHistoryQueries`（JSON 数组，上限 20） |
| 关注动态（参考） | `shared/src/commonMain/.../viewmodel/feed/FollowViewModel.kt` | `https://www.zhihu.com/api/v3/moments?limit=10&desktop=true`，与首页推荐共用 `BaseFeedViewModel` |

## 2. 行为表

| 功能 | 入口 | 用户操作 | 加载态 | 成功态 | 失败态 | 返回行为 | 登录态差异 |
|---|---|---|---|---|---|---|---|
| Web 首次加载首页 | `HomeScreen` → `HomeFeedViewModel.loadMore` | 进入首页/冷启动 | `isLoading=true` | `displayItems` 追加，`latestLoadedDisplayItems` 更新 | `errorMessage` 设置，toast 提示 | 留在首页 | 匿名可用（`allowGuestAccess=true`）；`d_c0` 缺失则跳过 touch 上报 |
| Web 翻页 | 滚到底部触发 `loadMore` | 下拉滚动 | `isLoading=true`（重复点击被拦截） | 追加条目，更新 `lastPaging` | 解码失败项跳过，整体异常进 `errorMessage` | 保留已加载条目 | 同上 |
| 下拉刷新 | `BaseFeedViewModel.pullToRefresh` | 下拉手势 | `isPullToRefresh=true`，`displayItems.clear()` | 重新填充 | `errorHandle` 设置 `errorMessage` | 列表回退到旧数据？否，已 clear | 同上 |
| Android 首页加载 | `AndroidHomeFeedViewModel.fetchFeeds` | 切换推荐模式到 ANDROID | `isLoading=true` | 解析 `ComponentCard` 入 `displayItems` | `handleMobileHomeFeedFailure` | 留在首页 | `loginForRecommendation=true` 时携带 cookies；否则匿名 |
| 混合首页加载 | `MixedHomeFeedViewModel.fetchFeeds` | 切换推荐模式到 MIXED（默认） | `isLoading=true` | Android + Web 并发 `async`，结果合并 | 各自捕获，互不影响 | 显示已成功部分 | 同上 |
| 点击 feed 卡片 | `onUiContentClick` | 点击条目 | 无 | 跳转 `navDestination`；若 `d_c0` 存在则 POST `lastread/touch` | 网络失败仅日志 | 导航到详情 | 匿名跳过 touch 上报 |
| 浏览曝光上报 | `markItemsAsTouched`（fetchFeeds 入口） | 自动（每次拉取前） | 无 | POST `lastread/touch`（touch 事件） | `Log.e("Browse-Touch", ...)` | 静默 | 匿名整体跳过 |
| 搜索提交 | `SearchScreen` IME action / 点击历史 / 点击热搜 | 输入并提交 | `viewModel.refresh` → `isLoading=true` | `displayItems` 填充，`lastPaging` 更新 | `handleFetchFailure("SearchViewModel", e)` | 显示结果列表 | `allowGuestAccess=false`，必须登录 |
| 搜索翻页 | 滚到底 `loadMore` | 下拉 | `isLoading=true` | 追加 | 解码失败项跳过 | 保留已加载 | 同上 |
| 搜索过滤器切换 | `updateSortOption`/`updateContentType`/`updateTimeRange` | 点击过滤项 | 立即 `refresh`（清空重拉） | 重新填充 | `errorMessage` | 列表清空后重载 | 同上 |
| 热搜加载 | `LaunchedEffect(showHotSearch, ...)` 进入搜索页 | 自动 | 无显式 loading | `hotSearchItems` 填充（前 15 条） | `runCatching` 静默吞 | 显示热搜列表 | 匿名行为待确认 |
| 热搜刷新 | 点击 `search_hot_refresh_button` | 点击 | 无 | 再次 fetch | 静默 | 列表保持 | 同上 |
| 搜索历史 | 输入提交时写入 | 自动 | 无 | 写入 SharedPreferences | 无 | 历史下拉刷新 | 用户创作限定搜索（member）时不记录/不显示历史 |
| 清空搜索历史 | `search_history_more_button` → 「清空搜索历史」 | 点击 | 无 | `searchHistoryItems.clear()` + 持久化 | 无 | 列表显示「暂无搜索历史」 | — |
| 用户创作限定搜索 | `Search(restrictedMemberHashId, restrictedMemberName)` | 从用户主页进入 | 同普通搜索 | 同上 | 同上 | 仅该 member 的创作 | 隐藏热搜与全局历史；URL 携带 `restricted_scene=member` 等参数 |
| 401 风控 | `fetchZhihuAuthenticatedJson` | 自动 | — | — | 触发 `ZhihuCredentialRefresher.refreshZhihuToken`（10 秒节流），重试一次 | — | 仅登录态 |
| 解码失败 | `PaginationViewModel.fetchFeeds` 内 `mapNotNull` | 自动 | — | 跳过该条 | `logDecodeFailure` 记录 | 其余条目正常展示 | — |
| 风控误判 | 响应非 JSON 或无 `$.data` | 自动 | — | — | 抛 `RuntimeException("您可能已被风控，请重新登录。")` | `errorMessage` 提示 | — |

## 3. 接口表

| 功能 | URL | HTTP 方法 | 请求头 | Cookie | 请求体 | 响应字段 | 分页字段 | 错误码 | 协议类型 |
|---|---|---|---|---|---|---|---|---|---|
| Web 首页推荐 | `https://api.zhihu.com/topstory/recommend` | GET | `x-zse-93: 101_3_3.0`、`x-zse-96: 2.0_{sig}`、`x-requested-with: fetch`、`User-Agent: DEFAULT_ZHIHU_USER_AGENT`（Linux Ubuntu UA）；query 参数 `include=data[*].content,excerpt,headline,target.author.badge_v2` | `d_c0`、`z_c0`（携带时签名；`d_c0` 缺失则不签名） | 无 | `data: []`（Feed 数组）、`paging: {next, is_end, ...}` | `paging.next`（下一页 URL，直接复用）、`paging.is_end` | 401→token 刷新重试；非 JSON/无 `data`→「风控」；204→null | JSON API |
| Android 首页推荐 | `https://api.zhihu.com/topstory/recommend` | GET | `User-Agent: com.zhihu.android/Futureve/10.61.0 ...`、`x-api-version: 3.1.8`、`x-app-version: 10.61.0`、`x-app-za: OS=Android&Release=12&Model=...`（无 zse 签名） | `loginForRecommendation=true` 时携带 zhihu.com cookies | 无 | `data: []`（`ComponentCard` 数组）、`paging` | 同上 | 同上（无签名） | JSON API |
| 浏览 touch 上报 | `https://www.zhihu.com/lastread/touch` | POST（`postSigned`） | `x-zse-93`、`x-zse-96`、`x-requested-with: fetch`；`Content-Type: multipart/form-data` | `d_c0` 必须存在 | `formData { append("items", "[[\"answer\",\"<id>\",\"touch\"]]") }`（JSON 字符串） | 仅看 HTTP status | 无 | 失败 `Log.e("Browse-Touch", body)` | JSON API（multipart） |
| 阅读 read 上报 | `https://www.zhihu.com/lastread/touch` | POST（`postSigned`） | 同上 | 同上 | `items` = `[["answer","<id>","read"]]`（或 article/pin） | 同上 | 无 | 同上 | 同上 |
| 阅读历史加入 | `https://www.zhihu.com/api/v4/read_history/add` | POST（`postSigned`） | `Content-Type: application/json` + zse 签名 | `d_c0` 必须存在 | `{"content_token":"<token>","content_type":"<answer\|article\|pin>"}` | 待确认 | 无 | 待确认 | JSON API |
| 搜索 | `https://www.zhihu.com/api/v4/search_v3?gk_version=gz-gaokao&t=general&q=<enc>&correction=1&offset=0&limit=20&search_source=Normal\|Filter&show_all_topics=0[&vertical=<answer\|article\|zvideo>&vertical_info=0,0,0,0,0,0,0,0,0,0,0,0][&sort=created_time\|upvoted_count][&time_interval=a_day\|a_week\|...][&restricted_scene=member&restricted_field=member_hash_id&restricted_value=<hash>&filter_fields=&lc_idx=0]` | GET | `x-zse-93/96`、`x-requested-with: fetch`、Web UA；`include=data[*].highlight,object,type` | 同 Web 首页 | 无 | `data: []`（SearchResult 数组，每项 `{type, id, object, highlight, index, hit_labels}`）、`paging` | 同上 | 同上；`allowGuestAccess=false` | JSON API |
| 热搜 | `https://www.zhihu.com/api/v4/search/hot_search` | GET | zse 签名 + Web UA；`include=""` | 同上 | 无 | `hot_search_queries: [{query, hot_show, label}]` | 无 | 同上 | JSON API |
| 关注动态 | `https://www.zhihu.com/api/v3/moments?limit=10&desktop=true` | GET | 同 Web 首页 | 同上 | 无 | `data: []`（MomentsFeed）、`paging` | 同上 | 同上 | JSON API |
| 关注推荐 | `https://api.zhihu.com/moments_v3?feed_type=recommend` | GET | 同上 | 同上 | 无 | 同上 | 同上 | 同上 | JSON API |
| 最近关注活跃用户 | `https://api.zhihu.com/moments/recent?type=raw` | GET | 同上 | 同上 | 无 | `data: [{actor:{id,url_token,name,avatar_url},unread_count}]` | 无 | 同上 | JSON API |

**通用说明**：
- **zse 签名范围**：所有走 `fetchJson` / `postSigned` / `deleteSigned` 的接口均签名（Web 首页、搜索、热搜、关注、touch 上报、阅读历史）。**Android 首页推荐不签名**（用 `mobileHomeFeedHttpClient()` 裸 GET + Android headers）。签名仅在 `d_c0` cookie 存在时添加，否则跳过。
- **x-zse-96 生成**：`"2.0_" + ZseSigner.encryptZseV4(md5Hex(zse93 + "+" + pathname + "+" + dc0 + "+" + body))`，其中 pathname 是 URL 去掉协议与 host 后的部分。
- **include 参数**：知乎 API 字段裁剪语法，`data[*].content,excerpt,...` 表示对 `data` 数组每项展开这些字段。
- **风控判定**：响应非 JsonObject 或缺 `$.data` 字段即抛「您可能已被风控，请重新登录」。

## 4. Feed 数据模型

**整体结构**（`Feed.kt`，纯 JSON，**无 Protobuf**——`FeedCodecTest` 451KB 全部为 JSON 反序列化测试）：

- `Feed` sealed interface，子类型 7 个：
  - `CommonFeed`（`@SerialName("feed")`，最常见，含 `verb`/`target`/`actionText`/`cursor`/`attachedInfo`/`actionCard`/`promotionExtra`）
  - `AdvertisementFeed`（`@SerialName("feed_advert")`，含 `ad.creatives[].landingUrl/title/description`）
  - `GroupFeed`（`@SerialName("feed_group")`，含 `list: List<CommonFeed>`，`flattenFeeds()` 会展开）
  - `QuestionFeedCard`（`@SerialName("question_feed_card")`，含 `cursor`/`targetType`/`isJumpNative`/`skipCount`）
  - `FeedItemIndexGroup`（`@SerialName("feed_item_index_group")`，在 `PaginationViewModel` 中被显式跳过：`// todo`）
  - `MomentsFeed`（`@SerialName("moments_feed")`，关注动态用）
  - `HotListFeed`（`@SerialName("hot_list_feed")`，含 `detailText`/`children`）

- `Feed.Target` sealed interface，子类型 5 个：
  - `AnswerTarget`（`@SerialName("answer")`）：`id: Long`、`question: QuestionTarget`、`voteupCount`、`commentCount`、`excerpt`、`content`、`thumbnail`/`thumbnails`、`segmentInfos`、`allowSegmentInteraction`、`relationship`、`isLabeled`、`answerType`、`favoriteCount`、`visitedCount`、`reshipmentSettings`、`createdTime=-1` 表示广告
  - `ArticleTarget`（`@SerialName("article")`）：`id`、`voteupCount`、`commentCount`、`content`、`created`/`updated`、`segmentInfos`、`visitedCount`、`favoriteCount`、`isLabeled`
  - `PinTarget`（`@SerialName("pin")`，「想法」）：`id`、`content: List<DataHolder.Pin.ContentItem>`（多态）、`contentHtml`、`excerptTitle`、`likeCount`/`commentCount`/`reactionCount`/`favoriteCount`
  - `QuestionTarget`（`@SerialName("question")`）：`id`、`_name`/`_title`（兼容老 API）、`type`、`questionType`、`answerCount`、`followerCount`、`detail`、`boundTopicIds`、`isFollowing`、`author`（`LegacyAuthorSerCompat` 兼容旧 API）
  - `VideoTarget`（`@SerialName("zvideo")`）：`id`、`voteCount`、`commentCount`、`title`、`description`、`excerpt`

- `Person`：`id`、`url`、`userType`、`urlToken`、`name`、`headline`（HTML 解码）、`avatarUrl`、`isOrg`、`gender`、`followersCount`（`@JsonNames("followerCount")` 兼容）、`isFollowing`/`isFollowed`、`badge`、`badgeV2`（注入 zh-plus 自定义徽章 `DataHolder.injectZhPlusAuthorBadge`）

- **与 Answer/Question/Article/Pin 的关系**：`DataHolder.Content` 是详情页统一模型，`Feed.Target` 是列表卡片模型；`FeedDisplayItem.raw: DataHolder.Content?` 可缓存详情以支持本地过滤。

- **SegmentInfo 用途**：回答/文章正文段落级评论与点赞元数据。`SegmentInfoParagraph(pid, text, marks[])` → `SegmentInfoMark(startIndex, endIndex, segInfo, masterSegInfo)` → `SegmentInfoMeta(segIds, isLike, likeCount, commentCount, myCommentCount, isSpan)`。`effectiveSegInfo` 优先 `segInfo` 回退 `masterSegInfo`。`BooleanCompatSerializer` 兼容 `true`/`1`/"true" 三种表示。

- **`FeedDisplayItem`**：UI 层统一卡片模型，`stableKey = navDestinationJson ?: feed?.target?.stableTargetKey ?: "$title|$summary|$details"`，用于去重。

## 5. 推荐模式

`RecommendationMode` 枚举（`RecommendationMode.kt`），4 种模式，持久化 key 稳定（`RecommendationModeTest` 锁定）：

| 模式 | displayName | key | 入口 ViewModel | URL | 协议特征 |
|---|---|---|---|---|---|
| WEB | Web 端推荐 | `server` | `HomeFeedViewModel` | `https://api.zhihu.com/topstory/recommend` | zse 签名 + Web UA，`include=data[*].content,excerpt,headline,target.author.badge_v2` |
| ANDROID | 安卓端推荐 | `android` | `AndroidHomeFeedViewModel` | 同上 | Android UA + `x-api-version=3.1.8`/`x-app-version=10.61.0`/`x-app-za=...`，无签名，解析 `ComponentCard` |
| LOCAL | 本地推荐 | `local` | `LocalHomeFeedViewModel` | 无（`initialUrl = error(...)`） | 依赖 `LocalRecommendationEngine`，不走网络 |
| MIXED | 混合推荐 | `mixed` | `MixedHomeFeedViewModel` | 同上 | `coroutineScope { async{android.fetchFeeds} ; async{web.fetchFeeds} }.joinAll()`，并发去重合并 |

**切换方式**：设置项 `recommendationMode`（SharedPreferences），`HomeScreen.kt` 读取后 `when` 选择 ViewModel。**默认值 `MIXED`**。

**缓存隔离**：每种模式有独立启动缓存文件 `home_feed_startup_cache_{key}.json`（上限 10 条）。

**特殊过滤**：`AndroidHomeFeedViewModel` 解析的卡片 `details` 末尾追加 `"· 手机版推荐"`。

## 6. 匿名 vs 登录差异

| 维度 | 匿名（无 `d_c0` 或 `loginForRecommendation=false`） | 登录 |
|---|---|---|
| Web 首页推荐 | `allowGuestAccess=true` 允许匿名；返回不带 cookie 的匿名 client（仍装 `HttpCache` + `UserAgent`） | 携带 `d_c0`/`z_c0`，签名 fetch |
| Android 首页推荐 | `mobileHomeFeedHttpClient()` 不装 `HttpCookies` storage | 装 `ZhihuCookieStorage(AccountData.data.cookies)` |
| 混合推荐 | 两路均匿名 | 两路均带 cookie |
| touch/read 上报 | `if (environment.authenticatedCookies()["d_c0"] == null) return` 整体跳过 | 上报，且 `reportedTouchedItems` 去重 |
| `addReadHistory` | `if (authenticatedCookies()["d_c0"] == null) return` 跳过 | POST `/api/v4/read_history/add` |
| zse 签名 | `signZhihuFetchRequest(cookies)` 中 `dc0 = cookies["d_c0"]?.takeIf { it.isNotBlank() } ?: return`，即无 `d_c0` 不加签名头 | 加 `x-zse-93/96` |
| 搜索 | `SearchScreen` 调 `rememberPaginationEnvironment(allowGuestAccess = false)`，必须登录 | 正常 |
| 热搜 | 走 `fetchJson`（`allowGuestAccess=false`），匿名不可用 | 正常 |
| 401 处理 | 不触发（无 token 可刷新） | `executeZhihuAuthenticatedRequest` 检测 401 → `ZhihuCredentialRefresher.refreshZhihuToken`（10 秒节流）→ 重试 |
| `z_c0` 空值保护 | `ZhihuCookieStorage.addCookie` 显式忽略 `z_c0` 为空字符串的 cookie（issue #25 修复） | — |

## 7. 搜索行为

**入口**：首页顶栏 `HOME_SEARCH_BUTTON_TAG` → `Search(query = "")`。

**页面结构**（`SearchScreen.kt`，testTag 来自测试）：
- `search_input`（占位符「搜索内容」或 member 模式「搜索 <name> 的创作」）
- `search_clear_button`（输入非空时显示）
- `search_back_button`（返回）
- `search_history_more_button` → 下拉菜单「清空搜索历史」/「前往设置关闭搜索历史」
- `search_hot_list`、`search_hot_refresh_button`、`search_hot_more_button` → 「关闭热搜显示」

**热搜**：
- URL `https://www.zhihu.com/api/v4/search/hot_search`（`ZHIHU_HOT_SEARCH_URL`）
- 响应 `hot_search_queries: [{query, hot_show, label}]`，取前 15 条
- 默认开启（`settings.getBoolean("showSearchHotSearch", true)`）
- member 模式下隐藏
- 进入页面 `LaunchedEffect` 自动 fetch 一次

**搜索建议**：**未实现**。代码中无 `search/suggest`、`search_hint`、`topSearch` 等接口调用，仅热搜 + 历史。

**搜索历史**：
- SharedPreferences key `searchHistoryQueries`，JSON 数组，上限 20（`SEARCH_HISTORY_MAX_SIZE`）
- 默认开启（`settings.getBoolean("showSearchHistory", true)`），可在设置关闭
- member 模式下隐藏全局历史且不写入

**搜索结果分页**：
- 首次 `limit=20&offset=0`，后续用 `paging.next`
- `SearchViewModel.fetchFeeds` 复用 `BaseFeedViewModel` 流程：fetch JSON → `data` 数组逐项 `decodeJson<SearchResult>` → `toFeed()` 转 `CommonFeed(verb="SEARCH_RESULT", target=...)` → `processResponse` 过滤屏蔽作者 → `flattenFeeds().map { createDisplayItem }` → 去重入 `displayItems`

**搜索范围**（`SearchContentType` 枚举）：

| 类型 | label | vertical 值 |
|---|---|---|
| All | 全部内容 | `""`（不传 vertical） |
| Answer | 回答 | `answer` |
| Article | 文章 | `article` |
| Video | 视频 | `zvideo` |

**注意**：项目内**未实现**「用户」「话题」独立搜索范围（无对应 enum 值），仅通过 `restrictedMemberHashId` 支持单个用户的创作限定搜索。

**排序**（`SearchSortOption`）：Default（综合，`""`）、Latest（最新发布，`created_time`）、MostVoted（最多赞同，`upvoted_count`）

**时间范围**（`SearchTimeRange`）：All/Day(`a_day`)/Week(`a_week`)/Month(`a_month`)/ThreeMonths(`three_months`)/HalfYear(`half_a_year`)/Year(`a_year`)

**URL 参数细节**（`SearchViewModelUrlTest` 与 `SearchViewModelTest` 锁定）：
- 任一非默认过滤器开启 → `search_source=Filter`，否则 `Normal`
- `vertical_info=0,0,0,0,0,0,0,0,0,0,0,0`（12 个 0，`SEARCH_VERTICAL_INFO` 常量）
- `gk_version=gz-gaokao`、`t=general`、`correction=1`、`show_all_topics=0`
- query 走 `encodeURLParameter(spaceToPlus = true)`
- member 限定额外携带 `filter_fields=`（空）、`lc_idx=0`、`restricted_scene=member`、`restricted_field=member_hash_id`、`restricted_value=<hashId>`

**搜索结果类型**（`SearchResult.kt`）：

| type | object 类型 | 处理 |
|---|---|---|
| `search_result` | `SearchObjectResult(target: Feed.Target)` | `toFeed()` 返回 `CommonFeed`，可显示 |
| `koc_box` | `SearchObjectKocBox`（KOC 推荐，含 `paid_column`） | `toFeed()` 返回 null，不显示 |
| `knowledge_ad` | `SearchObjectKnowledgeAd`（知识广告） | `toFeed()` 返回 null，不显示 |
| 其他 | null | `mapNotNull` 跳过 |

**Highlight**：`Highlight.title`/`description` 兼容 String 或 List<String>（`StringOrListSerializer`）。

**本地过滤**：`processResponse` 中按 `environment.blockedUserIds()` 过滤作者。

## 8. 脱敏样本路径建议

建议在 `HarmonyApp/docs/evidence/samples/home-search/` 下放置以下脱敏样本：

| 建议文件 | 内容 | 用途 |
|---|---|---|
| `home_feed_web_response_sample.json` | `topstory/recommend` 响应脱敏样本（保留 `data[0..2]` 与 `paging`，替换 id/author 名） | 验证 Web Feed 解析、`Feed.Target` 多态、`paging.next` |
| `home_feed_android_response_sample.json` | Android 端同 URL 响应（含 `ComponentCard` + `children` + `extra.business_ext_map.ori_content` Base64） | 验证 `parseMobileHomeFeedDisplayItem` |
| `home_feed_android_pin_card_sample.json` | 含 9 图想法的 `ComponentCard` | 验证 `ori_content` Base64 解码、`ContentImage` 构造 |
| `home_feed_group_feed_sample.json` | 含 `feed_group` 的响应 | 验证 `flattenFeeds` |
| `home_feed_moments_sample.json` | `moments_feed` 类型响应（`FollowViewModel`） | 验证 `sourceLabel`/`momentDesc` |
| `home_feed_advert_sample.json` | `feed_advert` 类型响应 | 验证广告过滤 |
| `search_v3_response_sample.json` | `search_v3` 响应（含 `search_result`/`koc_box`/`knowledge_ad` 三种 type） | 验证 `SearchResultSerializer` 多态 |
| `search_v3_member_restricted_sample.json` | member 限定搜索响应 | 验证 `restricted_value` 参数 |
| `hot_search_response_sample.json` | `/api/v4/search/hot_search` 响应 | 验证 `HotSearchItem` 解析 |
| `lastread_touch_request_sample.txt` | `lastread/touch` multipart 请求体样本 | 验证 touch/read 上报格式 |
| `zse96_signature_vectors.json` | 已知 `(zse93, url, dc0, body) → x-zse-96` 向量（dc0 用假值） | 验证 `ZhihuFetchSignature` 与 `ZseSigner` |
| `feed_target_question_legacy_author_sample.json` | `author` 字段为字符串（老 API）的 QuestionTarget | 验证 `LegacyAuthorSerCompat` |
| `segment_info_compat_sample.json` | `isLike: 1` / `isSpan: "true"` 等 BooleanCompat 用例 | 验证 `BooleanCompatSerializer` |
| `home_feed_startup_snapshot_sample.json` | `encodeHomeFeedStartupSnapshot` 输出 | 验证离线缓存编解码 |
| `error_risk_control_response_sample.json` | 非 JSON 或缺 `$.data` 的风控响应 | 验证风控判定路径 |
| `error_401_unauthorized_sample.json` | 401 响应（脱敏） | 验证 token 刷新节流 |

## 9. 风险与未确认项

详见 [06-risk-register.md](./06-risk-register.md)。

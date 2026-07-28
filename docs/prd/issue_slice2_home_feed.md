## Parent

第 2 批 PRD: `docs/prd/PRD_batch2_anonymous_feed_and_search.md`

## What to build

首页匿名信息流端到端纵向切片：从知乎 API 获取推荐数据，解析为 FeedCard 模型，通过 BasePaginationViewModel 分页管理，最终在 HomePage 用 `List + LazyForEach` 渲染卡片列表，支持下拉刷新、触底加载更多、去重和分页保护。

实现内容：

- `api/ZhihuApi.ets`：实现 `fetchHomeRecommend(pagingNext?: string): Promise<FeedCard[]>`，调用 `https://api.zhihu.com/topstory/recommend`，组装 zse 签名头、Cookie、`include` query 参数；从响应 `paging.next` 和 `paging.is_end` 提取分页信息；识别风控响应（非 JsonObject 或缺 `$.data` 抛 `ApiError(PARSE_ERROR, '风控')`）
- `model/FeedCard.ets`：首页卡片统一模型 `class FeedCard { stableKey: string; contentType: ContentType; title: string; excerpt: string; author: Author; thumbnail?: string; voteupCount: number; commentCount: number; rawId: string; }`，从 Feed.Target 多态响应解析为扁平 UI 模型；解析失败跳过该条目而非整批失败
- `viewmodel/BasePaginationViewModel.ets`：泛型分页基类，维护 `items: T[]`、`isLoading: boolean`、`isPullToRefresh: boolean`、`errorMessage: string`、`paging: Paging | null`；提供 `loadMore()`、`pullToRefresh()` 抽象方法、`addItems(newItems, dedupeByKey)` 去重逻辑、`isLoading` 重复请求保护、`isEnd` 停止加载
- `viewmodel/HomeFeedViewModel.ets`：继承 `BasePaginationViewModel<FeedCard>`，实现 `loadMore` 和 `pullToRefresh` 调用 `ZhihuApi.fetchHomeRecommend`
- `components/FeedCardView.ets`：单卡片 UI 组件，展示标题、作者头像和名字、摘要、缩略图、点赞数、评论数
- `components/StateView.ets`：统一的空/错/载状态视图（本切片仅实现加载态和空态，错误态在 Slice 3 完善）
- 改造 `pages/HomePage.ets`：从 PlaceholderPage 替换为 `Refresh + List + LazyForEach`，触底 `onReachEnd` 触发 `loadMore`，下拉触发 `pullToRefresh`；使用 `@ObservedV2 + @Trace` ViewModel
- 配套本地单元测试：FeedCard 解析、BasePaginationViewModel 去重和分页保护逻辑、HomeFeedViewModel loadMore/pullToRefresh

## Acceptance criteria

- [ ] 未登录用户打开首页自动加载推荐信息流（匿名访问 `allowGuestAccess=true`）
- [ ] 卡片显示标题、作者头像和名字、摘要、缩略图（加载失败显示失败图）、点赞数、评论数
- [ ] 下拉刷新清空当前列表并重新拉取首页
- [ ] 滚动到底部自动加载下一页，分页 `next` URL 来自响应 `paging.next`
- [ ] `paging.is_end=true` 时停止加载更多
- [ ] 分页返回重复条目时通过 `stableKey` 去重
- [ ] `isLoading=true` 时重复触发 `loadMore` 被拦截
- [ ] LazyForEach 使用 `stableKey` 作为唯一稳定 key，无错位
- [ ] 接口解析失败的单条目被跳过，不影响其他条目展示
- [ ] ViewModel 使用 `@ObservedV2 + @Trace`，UI 使用 `@ComponentV2 + @Local` 订阅

## Blocked by

- #1 (网络层基础)

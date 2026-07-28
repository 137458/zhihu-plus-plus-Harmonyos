## Parent

第 2 批 PRD: `docs/prd/PRD_batch2_anonymous_feed_and_search.md`

## What to build

搜索端到端纵向切片：搜索输入框、热搜榜单、搜索历史本地持久化、搜索结果列表分页。未登录时 UI 阻断搜索提交并提示"请先登录"（第 4 批接入真实登录后移除）。

实现内容：

- `api/ZhihuApi.ets` 扩展：
  - `search(query: string, filters?: SearchFilters, pagingNext?: string): Promise<SearchResultItem[]>`，调用 `https://www.zhihu.com/api/v4/search_v3`，组装 zse 签名头、Cookie、query 参数（`gk_version=gz-gaokao`、`t=general`、`correction=1`、`offset`、`limit=20`、`search_source=Normal`、`show_all_topics=0`、`vertical_info=0,0,0,0,0,0,0,0,0,0,0,0`）
  - `fetchHotSearch(): Promise<HotSearchItem[]>`，调用 `https://www.zhihu.com/api/v4/search/hot_search`，取前 15 条
- `model/SearchResult.ets`：搜索结果模型 `class SearchResultItem { type: string; id: string; title: string; excerpt: string; author?: Author; highlight?: string; }`，过滤 `search_result`/`koc_box`/`knowledge_ad` 中后两类（toFeed 返回 null 不显示，02 §7）
- `model/HotSearch.ets`：热搜模型 `class HotSearchItem { query: string; label: string; hotShow: number; }`
- `viewmodel/SearchViewModel.ets`：继承 `BasePaginationViewModel<SearchResultItem>`，额外维护 `query: string`、`hotSearchItems: HotSearchItem[]`、`searchHistory: string[]`（通过 `@kit.ArkData` preferences 持久化，key `searchHistoryQueries`，上限 20）；提供 `submitQuery(q)`、`loadHotSearch()`、`addHistory(q)`、`clearHistory()`、`clickHistory(q)` 方法；未登录时 `submitQuery` 设置 `errorMessage='请先登录'` 不发起请求
- `components/SearchResultView.ets`：单条搜索结果 UI，展示标题（含 highlight）、摘要、作者、类型标识
- `components/HotSearchItemView.ets`：热搜条目 UI，展示排名、query、label
- `components/SearchHistoryItemView.ets`：历史条目 UI，展示 query，点击搜索
- 改造 `pages/SearchPage.ets`：顶部 `TextInput` 搜索框（`onSubmit` 回调）+ 清空按钮；未输入时无法提交；热搜区（前 15 条）+ 历史区（最多 20 条，含"清空搜索历史"按钮）；结果区 `List + LazyForEach` 分页；未登录时提交弹出"请先登录"提示
- 配套本地单元测试：SearchViewModel query 提交、分页、历史持久化（addHistory/clearHistory/clickHistory）、热搜加载

## Acceptance criteria

- [ ] 搜索框输入为空时无法提交（onSubmit 被拦截）
- [ ] 提交搜索后显示结果列表，每项包含标题、摘要、作者、类型标识
- [ ] 搜索结果支持分页加载更多（`paging.next`）
- [ ] 搜索失败显示错误反馈和重试入口
- [ ] 搜索页显示热搜榜单（前 15 条），点击热搜词直接搜索
- [ ] 搜索历史保存在本地 preferences（key `searchHistoryQueries`，上限 20），点击历史词搜索
- [ ] 提供"清空搜索历史"按钮，清空后列表显示"暂无搜索历史"
- [ ] 未登录用户提交搜索时弹出"请先登录"提示，不实际发起请求（`allowGuestAccess=false`）
- [ ] 搜索历史不重复，新查询插入到最前
- [ ] LazyForEach 使用稳定唯一 key 无错位

## Blocked by

- #1 (网络层基础)

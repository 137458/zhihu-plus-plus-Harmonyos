## Parent

第 2 批 PRD: `docs/prd/PRD_batch2_anonymous_feed_and_search.md`

## What to build

第 2 批端到端验收切片：验证批次验收标准全部通过，补充 UI 测试覆盖关键链路，确认卡片点击预留路由参数（实际跳转第 3 批实现）。

实现内容：

- 扩展 `entry/src/ohosTest/ets/test/Ability.test.ets` UI 测试用例：
  - `coldStartLoadHomeFeed`：冷启动后首页自动加载推荐信息流，验证 FeedCard 列表可见
  - `pullToRefreshHomeFeed`：下拉刷新清空旧数据并重新加载
  - `loadMoreOnReachEnd`：滚动到底部触发加载更多
  - `homeErrorStateWithRetry`：模拟网络错误，验证错误状态显示和重试按钮交互
  - `searchSubmitShowsResults`：搜索提交后显示结果列表（需登录态，验证登录阻断）
  - `searchHotSearchClick`：点击热搜词触发搜索
  - `searchHistoryClickAndClear`：搜索历史点击和清空
  - `cardClickReservesRouteParams`：点击卡片预留路由参数（不真正跳转，验证参数构造正确）
- 验证批次验收标准（来自移植计划 §13.4）：
  - 未登录可加载匿名信息流
  - 首页刷新不会重复追加旧数据
  - 加载更多不会重复触发
  - 搜索完整链路可用（含登录阻断）
  - 断网、超时、空响应和解析失败都有页面反馈
  - 相同脱敏响应在 Android 参考预期和 ArkTS 解析结果之间一致
- 回归验证：确保第 1 批 HDS 主壳、路由、UiTest 用例仍通过

## Acceptance criteria

- [ ] 冷启动后首页自动加载推荐信息流（UI 测试验证）
- [ ] 下拉刷新清空旧数据并重新加载（UI 测试验证）
- [ ] 滚动到底部触发加载更多，不重复触发（UI 测试验证）
- [ ] 网络错误显示错误状态和重试按钮（UI 测试验证）
- [ ] 搜索提交显示结果列表（UI 测试验证，含登录阻断）
- [ ] 热搜点击触发搜索（UI 测试验证）
- [ ] 搜索历史点击和清空功能正常（UI 测试验证）
- [ ] 卡片点击预留路由参数正确（`QuestionDetailParams`/`AnswerDetailParams`/`ArticleDetailParams`）
- [ ] 断网、超时、空响应、解析失败都有页面反馈
- [ ] 第 1 批 HDS 主壳、路由、UiTest 用例回归通过
- [ ] 相同脱敏响应在 Android 参考预期和 ArkTS 解析结果之间一致（对照测试）

## Blocked by

- #2 (首页匿名信息流)
- #3 (首页空错载状态)
- #4 (搜索)

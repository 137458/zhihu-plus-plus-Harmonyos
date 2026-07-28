## Parent

第 2 批 PRD: `docs/prd/PRD_batch2_anonymous_feed_and_search.md`

## What to build

完善首页状态切换：空状态、错误状态（含重试按钮）、加载中骨架、断网提示、超时反馈、风控页识别。扩展 `components/StateView.ets` 支持三态（loading/empty/error）切换。

实现内容：

- 扩展 `components/StateView.ets`：支持 `loading`/`empty`/`error` 三态，error 态包含"重试"按钮回调
- 改造 `pages/HomePage.ets`：根据 ViewModel 的 `isLoading`、`items.length`、`errorMessage` 切换 StateView
- 添加骨架屏或加载指示器（首屏加载时显示，触底加载更多时在底部显示加载条）
- 网络断开反馈：通过 `ApiError.code === NETWORK_ERROR` 识别，给出"网络连接失败，请检查网络"提示
- 超时反馈：通过 `ApiError.code === TIMEOUT` 识别，给出"请求超时，请重试"提示
- 风控反馈：通过 `ApiError.code === RISK_CONTROL` 识别，给出"可能被风控，请稍后再试"提示
- 重试按钮：错误状态下点击重试触发 `pullToRefresh` 重新加载
- 配套 UI 测试：冷启动加载、下拉刷新、触底加载、空错载状态切换、重试按钮交互

## Acceptance criteria

- [ ] 首屏加载中显示骨架屏或加载指示器，不是突兀的空白
- [ ] 加载失败显示错误提示文案 + "重试"按钮，点击重试重新加载
- [ ] 加载成功但数据为空时显示空状态提示（如"暂无推荐内容"）
- [ ] 网络断开时显示"网络连接失败，请检查网络"
- [ ] 请求超时时显示"请求超时，请重试"
- [ ] 风控响应（非 JsonObject 或缺 `$.data`）显示"可能被风控，请稍后再试"
- [ ] 错误状态下点击"重试"按钮触发 `pullToRefresh` 重新加载
- [ ] 触底加载更多时在列表底部显示加载条，加载失败显示"加载失败，点击重试"

## Blocked by

- #2 (首页匿名信息流)

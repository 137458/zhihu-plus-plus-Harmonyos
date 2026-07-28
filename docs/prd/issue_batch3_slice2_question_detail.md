## Parent

PRD #6（第 3 批：内容详情与正文渲染）

## What to build

问题详情页端到端切片：从首页 question 卡片点击 → 进入问题详情页 → 显示标题/统计/描述 + 回答列表分页。

实现内容：

- 扩展 `api/ZhihuApi.ets`：新增 `fetchQuestionAnswers(questionId, pagingNext?, order?): Promise<QuestionAnswersResult>`，URL `https://www.zhihu.com/api/v4/questions/{id}/feeds?limit=20&order=default`，include 默认 `data[*].content,excerpt,headline,target.author.badge_v2`，响应解析为 FeedCard[] + Paging（复用 FeedCard.fromObject）
- 新增 `viewmodel/QuestionDetailViewModel.ets`：
  - 持有 `detail: QuestionDetail | null`、回答列表（复用 `BasePaginationViewModel<FeedCard>` 或独立维护 `answers: FeedCard[]`/`paging`/`isLoading`）
  - `load(questionId, previewTitle?)`：先设 previewTitle 立即展示，再请求详情接口，命中缓存直接用
  - 回答列表 `loadMore`/`pullToRefresh` 调用 fetchQuestionAnswers
  - 空错载状态管理（复用第 2 批 StateView 模式）
- 改造 `pages/QuestionDetailPage.ets`（从占位页真实化）：
  - HdsNavigation + HdsNavigationTitleMode.MINI + ScrollEffectType.GRADIENT_BLUR + systemMaterialEffect(IMMERSIVE)（模式三混合写法，与 PlaceholderPage 一致）
  - 顶部：问题标题（previewTitle 立即展示，请求返回后替换为真实 title）+ 统计栏（回答数/浏览数/评论数/关注数）+ 问题描述（detail HTML，首版用 Text 或简易 HTML 渲染，ArkWeb 正文容器由 Slice 3 建立）
  - 下方：回答列表 List + LazyForEach + FeedCardDataSource，支持触底加载更多、下拉刷新
  - 空/错/载状态切换（StateView）
  - 回答列表项点击预留跳转 AnswerDetailPage（Slice 3 实现，本切片预留参数 `AnswerDetailParams{answerId, questionId}`）
- 改造 `pages/HomePage.ets`：卡片点击回调根据 `contentType === QUESTION` 分发到 `navPathStack.pushPathByName(RouteName.QUESTION_DETAIL, {questionId, previewTitle})`（移除或保留第 1 批测试入口按钮 home_test_push 作为调试开关）
- 扩展 `ohosTest/ets/test/ContentDetail.test.ets`：QuestionDetailViewModel.load 成功/失败/缓存命中、回答列表分页累加/下拉刷新
- 扩展 `ohosTest/ets/test/Ability.test.ets`：首页 question 卡片点击 → 验证 page_question_detail_title 可见 → 返回回到首页

## Acceptance criteria

- [ ] 首页 question 卡片点击进入问题详情页（验证 page_question_detail_title 可见）
- [ ] 问题详情页顶部立即显示 previewTitle，请求返回后显示真实 title
- [ ] 问题详情页显示回答数、浏览数、评论数、关注数统计
- [ ] 问题详情页显示问题描述（detail 字段）
- [ ] 回答列表 LazyForEach 渲染，触底加载更多，下拉刷新清空重拉
- [ ] 回答列表使用 FeedCard 模型和 FeedCardDataSource
- [ ] 详情缓存命中时直接用缓存，不重复请求
- [ ] 加载/空/错状态切换正确，错误态有重试按钮
- [ ] 返回回到首页，首页滚动位置保留
- [ ] 问题详情页使用 HDS（HdsNavigation + MINI + GRADIENT_BLUR + IMMERSIVE 材质）
- [ ] 设备单元测试 + UI 测试通过
- [ ] ArkTS 严格检查通过，hvigorw assembleHap BUILD SUCCESSFUL

## Blocked by

- #7（Slice 1：详情领域模型与 API 基础）

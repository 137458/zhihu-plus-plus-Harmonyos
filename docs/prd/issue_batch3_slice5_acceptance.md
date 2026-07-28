## Parent

PRD #6（第 3 批：内容详情与正文渲染）

## What to build

第 3 批端到端验收切片：验证批次验收标准全部通过，补充深色模式、平板布局、外链拦截、缓存命中等边界场景测试，同步文档。

实现内容：

- 扩展 `entry/src/ohosTest/ets/test/Ability.test.ets` UI 测试用例：
  - `navigateToQuestionDetail`：首页 question 卡片点击 → 验证 page_question_detail_title 可见 → 统计信息可见 → 返回
  - `navigateToAnswerDetail`：首页 answer 卡片点击 → 验证 page_answer_detail_title 可见 → ArkWeb 容器可见 → 返回
  - `navigateToArticleDetail`：首页 article 卡片点击 → 验证 page_article_detail_title 可见 → ArkWeb 容器可见 → 返回
  - `detailPageErrorStateWithRetry`：模拟网络错误，验证详情页错误状态和重试按钮
  - `detailPageLoadingState`：验证详情页加载指示器可见
  - `arkWebExternalLinkBlocked`：验证外链点击被拦截（不可信主机不跳转）
  - `detailCacheHitSkipsRequest`：重复进入同一详情页验证缓存命中（不重复请求）
- 验证批次验收标准（来自移植计划 §13.5）：
  - 首页或搜索结果可进入问题详情、回答详情和文章详情
  - 正文可滚动，图片、表格和公式有可观察结果
  - 外链不能跳转到不受信任的协议或主机
  - ArkWeb 销毁后没有残留监听器、定时器或页面引用
  - 正文失败不会导致 Ability 崩溃
- 深色模式验证：详情页正文可读性（背景色/文字色/代码块色适配）
- 平板布局验证：正文宽度合理，不撑满屏幕
- 回归验证：第 1 批 HDS 主壳、第 2 批信息流/搜索 UiTest 用例仍通过
- 文档同步：更新 `docs/Android到HarmonyOS移植计划.md` 第 3 批完成记录

## Acceptance criteria

- [ ] 首页/搜索结果可进入三类详情页（UI 测试验证）
- [ ] 详情页正文可滚动，图片/表格/公式有可观察结果
- [ ] 外链点击被拦截，不跳转到不可信协议或主机（UI 测试验证）
- [ ] ArkWeb 销毁后无残留监听器/定时器/页面引用（代码审查 + 测试验证）
- [ ] 正文加载失败不会导致 Ability 崩溃（UI 测试验证）
- [ ] 深色模式下正文可读（手动验证）
- [ ] 平板布局正文宽度合理（手动验证）
- [ ] 缓存命中时不重复请求（UI 测试验证）
- [ ] 第 1 批 HDS 主壳、第 2 批信息流/搜索 UiTest 用例回归通过
- [ ] 移植计划第 3 批完成记录已更新

## Blocked by

- #9（Slice 2：问题详情页）
- #8（Slice 3：回答详情页 + ArkWeb 正文容器）
- #10（Slice 4：文章详情页）

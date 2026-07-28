## Parent

PRD #6（第 3 批：内容详情与正文渲染）

## What to build

文章详情页切片：复用 Slice 3 建立的 ArticleWebContainer，实现专栏文章端到端阅读。

实现内容：

- 新增 `viewmodel/ArticleDetailViewModel.ets`：
  - 持有 `detail: ArticleDetail | null`、`isLoading`、`errorMessage`
  - `load(articleId)`：请求 fetchArticleDetail，命中缓存直接用
- 改造 `pages/ArticleDetailPage.ets`（从占位页真实化）：
  - HdsNavigation + HdsNavigationTitleMode.MINI + ScrollEffectType.GRADIENT_BLUR + systemMaterialEffect(IMMERSIVE)
  - 顶部：文章标题 + 作者卡（头像/姓名/简介）+ 发布/更新时间
  - 中间：ArticleWebContainer 渲染 content HTML（复用 Slice 3 组件）
  - 底部：统计栏（点赞数/评论数）
  - 空/错/载状态切换（StateView）
- 接入卡片点击跳转：
  - 首页 article 卡片点击 → `navPathStack.pushPathByName(RouteName.ARTICLE_DETAIL, {articleId})`
  - 搜索结果 article 类型点击 → 同上
- 扩展 `ohosTest/ets/test/ContentDetail.test.ets`：ArticleDetailViewModel.load 成功/失败/缓存命中
- 扩展 `ohosTest/ets/test/Ability.test.ets`：首页 article 卡片点击 → 验证 page_article_detail_title 可见 → ArkWeb 容器可见 → 返回

## Acceptance criteria

- [ ] 文章详情页显示标题 + 作者卡 + 正文 + 统计栏
- [ ] ArticleWebContainer 复用 Slice 3 组件，不重复创建
- [ ] 详情缓存命中时直接用缓存
- [ ] 加载/空/错状态切换正确，错误态有重试按钮
- [ ] 首页 article 卡片点击进入文章详情页
- [ ] 搜索结果 article 类型点击进入文章详情页
- [ ] 返回回到来源页
- [ ] 文章详情页使用 HDS（HdsNavigation + MINI + GRADIENT_BLUR + IMMERSIVE 材质）
- [ ] 设备单元测试 + UI 测试通过
- [ ] ArkTS 严格检查通过，hvigorw assembleHap BUILD SUCCESSFUL

## Blocked by

- #7（Slice 1：详情领域模型与 API 基础）
- #8（Slice 3：回答详情页 + ArkWeb 正文容器，提供 ArticleWebContainer）

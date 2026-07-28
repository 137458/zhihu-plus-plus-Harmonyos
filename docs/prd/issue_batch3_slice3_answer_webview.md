## Parent

PRD #6（第 3 批：内容详情与正文渲染）

## What to build

回答详情页 + ArkWeb 正文容器切片：建立统一正文容器组件，实现回答详情端到端阅读。

实现内容：

- 新增 `web/ArticleWebContainer.ets`（ArkWeb 正文容器）：
  - 基于 `@ohos.web.web` 的 `Web` 组件封装
  - 接收 `htmlContent: string`、`onPageFinish?: () => void`、`onError?: (err) => void`、`onLinkClick?: (url) => void`、`onImageClick?: (url) => void` 回调
  - 内部将知乎 `content` HTML 包装为完整 HTML 文档：`<html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><meta name="referer" content="always"><style>{深色/浅色 CSS}</style></head><body>{content}</body></html>`
  - 深色模式 CSS：根据 `ConfigurationConstant.ColorMode` 注入 `--bg-color`/`--text-color`/`--code-bg`/`--link-color` 等 CSS 变量
  - 图片防盗链：`<meta name="referer" content="always">` 或 `<base href="https://www.zhihu.com/">`
  - 安全：HTTPS only（`onLoadIntercept` 校验协议），可信主机白名单（`www.zhihu.com`、`pic1-4.zhimg.com`、`picx/pica/picb/picd.zhimg.com`、`equation` 路径），外链点击拦截（`onControllerAttached` 注册 JS 钩子或 `WebControllerClient.onLoadIntercept` 校验 URL）
  - 最小化 JS 桥接：仅暴露图片点击和链接点击事件给原生
  - 生命周期：`onPageBegin`/`onPageFinish`/`onErrorReceive`/组件销毁时清理（`onControllerAttached`/`onAudioExit` 等）
- 新增 `viewmodel/AnswerDetailViewModel.ets`：
  - 持有 `detail: AnswerDetail | null`、`isLoading`、`errorMessage`
  - `load(answerId)`：请求 fetchAnswerDetail，命中缓存直接用
  - previewTitle 从 AnswerDetailParams 无（回答无 previewTitle），但可显示所属 question.title 作为标题
- 改造 `pages/AnswerDetailPage.ets`（从占位页真实化）：
  - HdsNavigation + HdsNavigationTitleMode.MINI + ScrollEffectType.GRADIENT_BLUR + systemMaterialEffect(IMMERSIVE)
  - 顶部：作者卡（头像/姓名/简介）+ 所属问题标题（可点击返回问题详情）
  - 中间：ArticleWebContainer 渲染 content HTML
  - 底部：统计栏（点赞数/评论数/感谢数）
  - 空/错/载状态切换（StateView）
- 接入卡片点击跳转：
  - 首页 answer 卡片点击 → `navPathStack.pushPathByName(RouteName.ANSWER_DETAIL, {answerId, questionId?})`
  - 问题详情回答列表项点击 → 同上（Slice 2 已预留）
- 扩展 `ohosTest/ets/test/ContentDetail.test.ets`：AnswerDetailViewModel.load 成功/失败/缓存命中
- 扩展 `ohosTest/ets/test/Ability.test.ets`：首页 answer 卡片点击 → 验证 page_answer_detail_title 可见 → ArkWeb 容器可见 → 返回

## Acceptance criteria

- [ ] ArticleWebContainer 组件封装 ArkWeb Web，接收 htmlContent 和回调
- [ ] 知乎 content HTML 被包装为完整 HTML 文档（含 charset/viewport/referer meta + CSS）
- [ ] 深色模式正文可读（CSS 变量切换背景色/文字色/代码块色）
- [ ] 图片防盗链处理（referer meta 或 base href）
- [ ] HTTPS only，非 HTTPS URL 被拦截
- [ ] 外链点击被拦截或校验，不跳转到不可信主机
- [ ] ArkWeb 销毁后无残留监听器/定时器/页面引用
- [ ] 回答详情页显示作者卡（头像/姓名/简介）+ 正文 + 统计栏
- [ ] 回答详情页显示所属问题标题
- [ ] 详情缓存命中时直接用缓存
- [ ] 加载/空/错状态切换正确
- [ ] 首页 answer 卡片点击进入回答详情页
- [ ] 问题详情回答列表项点击进入回答详情页
- [ ] 返回回到来源页
- [ ] 回答详情页使用 HDS（HdsNavigation + MINI + GRADIENT_BLUR + IMMERSIVE 材质）
- [ ] 设备单元测试 + UI 测试通过
- [ ] ArkTS 严格检查通过，hvigorw assembleHap BUILD SUCCESSFUL

## Blocked by

- #7（Slice 1：详情领域模型与 API 基础）

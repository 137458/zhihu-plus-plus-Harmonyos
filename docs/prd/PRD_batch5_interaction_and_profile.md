# 第 5 批 PRD：核心互动与个人页

## Problem Statement

当前匿名阅读链路（首页信息流、搜索、问题/回答/文章详情）已完整可用，登录与会话管理（第 4 批）已就绪。但用户登录后无法进行任何互动操作——不能点赞、收藏、评论，也没有个人主页查看自己的资料和内容。

## Solution

在第 5 批中，实现核心互动能力（点赞、收藏）和个人主页，使登录用户能够参与内容互动并查看个人资料。

## User Stories

1. 作为已登录用户，我可以在回答详情页点赞/取消点赞，以便表达对回答的认可。
2. 作为已登录用户，我可以在文章详情页点赞/取消点赞，以便表达对文章的认可。
3. 作为已登录用户，我可以在回答/文章详情页收藏/取消收藏，以便将内容保存到收藏夹。
4. 作为已登录用户，我可以在个人主页查看我的头像、昵称、简介和统计数据。
5. 作为已登录用户，我可以在个人主页查看我的回答列表和文章列表。
6. 作为已登录用户，我可以在个人主页管理我的收藏夹。
7. 作为未登录用户，点击点赞/收藏按钮时跳转到登录页。
8. 作为已登录用户，我可以在详情页查看根评论列表。
9. 作为已登录用户，快速重复点击点赞/收藏不会产生重复请求。
10. 作为已登录用户，点赞/收藏失败后状态自动回滚到操作前。
11. 作为用户，我可以在设置页调整主题模式（深色/浅色/跟随系统）。
12. 作为用户，我可以在设置页调整正文字号。

## Implementation Decisions

### 架构决定

1. **点赞状态管理**：新增 `VotersViewModel` 单例（@ObservedV2 + @Trace），管理点赞/取消点赞操作的状态和节流。
   - 回答点赞：`POST /api/v4/answers/{id}/voters`，body `{"type":"up"|"neutral"}`（首发不支持踩）
   - 文章点赞：`POST /api/v4/articles/{id}/voters`，body `{"voting":1|0}`
   - 取消点赞：回答传 `neutral`，文章传 `0`（复用同一 endpoint，不是 DELETE）
   - 所有请求走 `x-zse-93/96` 签名

2. **收藏状态管理**：新增 `CollectionsViewModel` 单例（@ObservedV2 + @Trace），管理收藏/取消收藏操作。
   - 收藏/取消：`PUT https://api.zhihu.com/collections/contents/{contentType}/{id}`，form-urlencoded body
   - 不走 zse 签名，仅依赖 Cookie
   - 内容收藏夹列表：`GET /api.zhihu.com/collections/contents/{contentType}/{id}?limit=50`

3. **评论列表**：新增 `CommentViewModel`（@ObservedV2 + @Trace），管理评论列表加载和分页。
   - 根评论列表：`GET /api/v4/comment_v5/{contentType}s/{id}/root_comment?order_by=score|ts`
   - 走 zse 签名
   - 首发只读，不支持发表评论

4. **个人主页增强**：扩展 `ProfilePage`，新增 `ProfileViewModel` 管理个人资料和列表数据。
   - 个人资料：`GET https://api.zhihu.com/people/{identifier}`（依赖 SessionViewModel 已有能力）
   - 回答列表：`GET /api/v4/members/{urlToken}/answers?sort_by=voteups`
   - 文章列表：`GET /api/v4/members/{urlToken}/articles?sort_by=created`

5. **设置页**：扩展 `SettingsPage`，实现主题切换和正文字号设置。
   - 主题模式持久化到 Preferences
   - 正文字号持久化到 Preferences
   - 复用已有 PreferencesUtil

### 防重复与回滚

- 点赞/收藏操作设置 `isLoading` 标志，操作完成前禁止再次点击
- 操作失败后恢复原始 UI 状态 + Toast 提示
- 401 触发 SessionViewModel 的 refreshAndRetry 流程

### 未登录处理

- 点赞/收藏按钮点击时检查 `isLoggedIn`
- 未登录 → 弹出 Toast 提示"请先登录" + 跳转 LoginPage（复用 Index.ets 路由守卫模式）

## Testing Decisions

### 测试原则

- 只测试外部行为（API 请求构造、状态转换、防重复），不测试实现细节
- 优先级：单元测试 > ViewModel 状态测试 > UI 测试

### 测试模块

- **VotersApi.test.ets**：验证回答/文章点赞请求体构造、签名头注入
- **CollectionsApi.test.ets**：验证收藏 PUT 请求体（form-urlencoded）构造
- **VotersViewModel.test.ets**：验证状态转换（idle → loading → success/error）、防重复节流、失败回滚
- **CollectionsViewModel.test.ets**：同上

### 测试先例

- 参考 `AuthApi.test.ets`（API 请求构造）、`NetworkClient.test.ets`（状态转换）

## Out of Scope

- 评论发表/回复（第 9 批）
- 踩（反对）功能（回答支持 down，首发暂不实现）
- 赞同者列表展示
- 关注/取关用户
- 完整收藏夹管理（新建/删除收藏夹）
- 浏览历史
- 平板双栏个人页布局
- 头像上传和编辑
- 个人主页的「关注/粉丝/动态」tab

## Further Notes

- 点赞/收藏接口详情见 `docs/evidence/04-interaction-and-profile.md` §3-§5
- 评论接口详情见同文档 §6
- 个人页接口详情见同文档 §7
- 所有未登录操作统一通过 `onLoginClick` 回调跳转，不直接 push LoginPage（保持路由控制集中）
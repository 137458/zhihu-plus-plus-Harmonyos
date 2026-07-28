# 互动与个人页证据表

> 调研范围：`zhihu-plus-plus/` 下点赞、收藏、评论、个人页、关注、基础设置相关源码及测试。所有结论以源码为据，无法确认的字段标注「待确认」。

## 1. 功能模块清单

| 模块 | Android 入口文件 | 简述 |
|---|---|---|
| 点赞（voters） | `shared/.../viewmodel/VotersSupport.kt` + `...\viewmodel\ArticleViewModel.kt` | 回答/文章的赞同、反对、中立切换；赞同者列表分页加载；社交关系文案加载 |
| 收藏（collections） | `...\viewmodel\CollectionsViewModel.kt` + `...\viewmodel\CollectionContentViewModel.kt` | 用户收藏夹列表、收藏夹详情分页、内容收藏/取消收藏（batch 操作）、新建收藏夹、收藏夹导出 HTML ZIP |
| 评论（comments） | `...\viewmodel\comment\BaseCommentViewModel.kt` + `RootCommentViewModel.kt` + `ChildCommentViewModel.kt` + `...\shared\comment\ZhihuCommentUtils.kt` + `...\shared\viewmodel\CommentItem.kt` | 根评论、子评论（楼中楼）、评论排序、点赞评论、回复评论、屏蔽过滤、ZhPlus 作者评论区策略 |
| 个人页 | `...\ui\PeopleScreen.kt` | 自己/他人个人页统一入口；含回答/文章/动态/收藏/提问/想法/专栏/粉丝/关注/关注订阅 10 个 tab |
| 关注 | `...\viewmodel\feed\FollowViewModel.kt` + `...\ui\PeopleScreen.kt` | 关注 feed、关注推荐 feed、最近活跃关注用户、关注/取关用户、关注问题/话题/专栏/收藏夹列表 |
| 基础个人设置 | `...\shared\theme\ThemeMode.kt` + `...\ui\AccountSettingScreen.kt` + `...\ui\subscreens\AppearanceSettingsScreen.kt` 等 | 主题模式、字号、行间距、底栏配置、双击行为等本地偏好；账号设置页为入口聚合 |

## 2. 行为表

| 功能 | 入口 | 用户操作 | 加载态 | 成功态 | 失败态 | 返回行为 | 登录态差异 |
|---|---|---|---|---|---|---|---|
| 切换赞同/反对 | `ArticleViewModel.toggleVoteUp` | 点击赞同/反对按钮 | 无独立 loading（同步切换） | `voteUpState` 更新；`voteup_count` 来自响应；回答额外刷新 voters 与 endorsement | `userMessages.showShortMessage("点赞失败: ${e.message}")` | 留在当前文章页 | 未登录触发 401 → 自动刷新 token；匿名用户无法投票 |
| 加载赞同者列表 | `ArticleViewModel.loadMoreVoters` | 滚动到 voters 列表底部 | `votersLoading=true` | 追加去重作者；`votersTotal` 取 `paging.totals` 或 `voteUpCount` | `votersError=message` | 仅 Answer 类型触发；Article 不加载 voters | 登录态获取完整列表；匿名可能受限 |
| 收藏/取消收藏内容 | `ArticleViewModel.toggleFavorite` | 点击收藏夹切换 | 无独立 loading | 重新拉取 `loadCollections`；toast「收藏成功」/「取消收藏成功」 | toast「收藏操作失败」 | 留在当前文章页 | 必须登录 |
| 新建收藏夹 | `ArticleViewModel.createNewCollection` | 输入标题/描述/公开 | 无独立 loading | 重新拉取 `loadCollections` | 无显式错误提示 | 留在当前页 | 必须登录 |
| 加载收藏夹内容 | `CollectionContentViewModel.refresh` | 进入收藏夹详情 | `isLoading=true` | `collection` 元信息 + `displayItems` 填充 | 待确认 | 留在收藏夹页 | 公开收藏夹匿名可访问；私密需登录 |
| 切换评论排序 | `BaseCommentViewModel.changeSortOrder` | 点击「按热度/按时间」chip | 触发 `refresh` | 重新拉取根评论 | `errorMessage` 文本 | 留在评论面板 | 匿名可读；登录态可发评论 |
| 发表根评论 | `RootCommentViewModel.submitComment` | 输入文本并点击发送 | 无独立 loading | 解析响应为新 `Comment` 插入到 `allData[0]`；调用 `onSuccess` | `errorMessage="评论发送失败: ${status}"` | 留在评论面板 | 必须登录 |
| 发表子评论 | `ChildCommentViewModel.submitComment` | 在子评论输入框发送 | 无独立 loading | 同上；附加 `reply_comment_id` | 同上 | 留在楼中楼面板 | 必须登录 |
| 点赞评论 | `BaseCommentViewModel.toggleLikeComment` | 点击评论点赞按钮 | `isLikeLoading=true` | 调用 `onSuccess` 由调用方更新本地状态 | `errorMessage="操作失败：${status}"` | 留在评论面板 | 必须登录 |
| 关注/取关用户 | `PersonViewModel.toggleFollow` | 点击「关注/取消关注」 | 无独立 loading | `followerCount` 来自响应或本地 ±1；`isFollowing` 翻转 | 抛异常由 UI 弹「操作失败」 | 留在个人页 | 必须登录 |
| 拉黑/取消拉黑 | `PersonViewModel.toggleBlock` | 点击「拉黑/取消拉黑」 | 无独立 loading | `isBlocking` 翻转 | 抛异常由 UI 弹「操作失败」 | 留在个人页 | 必须登录 |
| 屏蔽推荐/屏蔽其提问 | `PersonViewModel.toggleRecommendationBlock` / `toggleQuestionAuthorBlock` | 点击对应按钮 | 无独立 loading | 本地屏蔽库增删；状态翻转；toast 提示 | 抛异常由 UI 弹「操作失败」 | 留在个人页 | 本地数据库操作，不依赖登录态 |
| 加载个人页资料 | `PersonViewModel.load` | 进入个人页 | UI 待确认 | 头像/姓名/简介/统计/认证徽章/GitHub 社交链接填充 | 抛异常由 UI 弹「加载用户信息失败」 | 留在个人页 | 匿名可访问公开字段；关系字段需登录 |
| 切换 tab | `PeopleScreen` HorizontalPager | 点击 tab 或滑动 | 各子 ViewModel `loadMore` 触发 | 子列表填充 | 各子 VM 错误处理 | 留在个人页 | 子列表多需登录 |

## 3. 接口表

> 协议类型说明：**JSON API** = `api.zhihu.com` / `www.zhihu.com/api/v4` 等返回 JSON 的接口；**Web API** = 走 www.zhihu.com 的 Web 端接口（含 x-zse 签名）

| 功能 | URL | HTTP 方法 | 请求头 | Cookie | 请求体 | 响应字段 | 分页字段 | 错误码 | 协议类型 |
|---|---|---|---|---|---|---|---|---|---|
| 赞同/反对回答 | `https://www.zhihu.com/api/v4/answers/{id}/voters` | POST | `x-zse-93`, `x-zse-96`, `x-requested-with: fetch`, `Content-Type: application/json` | `z_c0`, `d_c0` 等 | `{"type":"up"\|"down"\|"neutral"}` | `voteup_count:Int` | 无 | 401（未登录，触发 token 刷新） | Web API |
| 赞同文章 | `https://www.zhihu.com/api/v4/articles/{id}/voters` | POST | 同上 | 同上 | `{"voting":1\|0}`（1=赞，0=取消，无 down） | `voteup_count:Int` | 无 | 同上 | Web API |
| 回答赞同者列表 | `https://www.zhihu.com/api/v4/answers/{id}/upvoters?limit=10&offset=0` | GET | `x-zse-93`, `x-zse-96`, `x-requested-with: fetch` | `d_c0`（匿名也可） | 无 | `data:List<Author>`、`paging:{next,is_end,totals}` | `paging.next`（http→https）、`paging.is_end` | 待确认 | Web API |
| 回答关系（认可文案） | `https://www.zhihu.com/api/v4/answers/{id}/relationship?desktop=true` | GET | 同上 | 同上 | 无 | `{type,text}`（`AnswerRelationshipEndorsement`） | 无 | 待确认 | Web API |
| 内容所在收藏夹列表 | `https://api.zhihu.com/collections/contents/{contentType}/{id}?limit=50` | GET | 待确认（fetchJson 走签名） | 同上 | 无 | `data:List<Collection>`、`paging` | `paging` | 待确认 | JSON API |
| 收藏/取消收藏内容 | `https://api.zhihu.com/collections/contents/{contentType}/{id}` | PUT | `Content-Type: application/x-www-form-urlencoded`（未走 postSigned，直接 httpClient.put） | 同上 | `add_collections={id}` 或 `remove_collections={id}`（form-urlencoded） | 仅看 HTTP status | 无 | 非 2xx → toast 失败 | JSON API |
| 新建收藏夹 | `https://www.zhihu.com/api/v4/collections` | POST | `x-zse-93`, `x-zse-96`, `Content-Type: application/json`（postSigned） | 同上 | `{"title":String,"description":String,"is_public":Boolean}` | 待确认 | 无 | 待确认 | Web API |
| 用户收藏夹列表 | `https://www.zhihu.com/api/v4/people/{urlToken}/collections` | GET | 同上签名 | 同上 | 无 | `data:List<Collection>`、`paging` | `paging.next` | 待确认 | Web API |
| 收藏夹详情 | `https://www.zhihu.com/api/v4/collections/{id}` | GET | 同上 | 同上 | 无 | `{collection:Collection}` | 无 | 待确认 | Web API |
| 收藏夹条目列表 | `https://www.zhihu.com/api/v4/collections/{id}/items` | GET | 同上 | 同上 | 无 | `data:List<CollectionItem{created,content:Feed.Target}>`、`paging` | `paging.next` | 待确认 | Web API |
| 根评论列表 | `https://www.zhihu.com/api/v4/comment_v5/{contentType}s/{id}/root_comment?order_by=score\|ts` | GET | 同上签名 | 同上 | 无 | `data:List<Comment>`、`paging` | `paging.next` | 待确认 | Web API |
| 子评论列表 | `https://www.zhihu.com/api/v4/comment_v5/comment/{commentId}/child_comment` | GET | 同上 | 同上 | 无 | 同上 | 同上 | 待确认 | Web API |
| 发表评论 | `https://www.zhihu.com/api/v4/comment_v5/{answers\|articles\|pins\|questions\|{contentType}s}/{id}/comment`（segment 附加 `?segment_id={segmentId}`） | POST | `x-zse-93`, `x-zse-96`, `Content-Type: application/json` | `z_c0`, `d_c0` | `{"content":"<p>...</p>","reply_comment_id":String?}` | 返回新 `Comment` 对象 | 无 | 非 2xx → `errorMessage` | Web API |
| 点赞评论 | `https://www.zhihu.com/api/v4/comments/{commentId}/like` | POST | 同上签名（postSigned） | `z_c0`, `d_c0` | 无 | 仅看 HTTP status | 无 | 非 2xx → `errorMessage` | Web API |
| 取消点赞评论 | `https://www.zhihu.com/api/v4/comments/{commentId}/like` | DELETE | 同上签名（deleteSigned） | 同上 | 无 | 同上 | 无 | 同上 | Web API |
| 个人页资料 | `https://api.zhihu.com/people/{identifier}` | GET | `x-zse-93`, `x-zse-96`（fetchJson 走签名）；`include` 参数 | `d_c0`（匿名也可访问公开字段） | 无 | `People{id,urlToken,name,avatarUrl,headline,gender,isFollowing,isBlocking,followerCount,followingCount,answerCount,articlesCount,badgeV2,...}` | 无 | 待确认 | JSON API |
| 个人页详情（社交链接） | `https://api.zhihu.com/people/{identifier}/profile/detail` | GET | 同上 | 同上 | 无 | `People{socialMedias:[{title,link,icon,modules:[{title,value}]}]}` | 无 | 失败不影响主资料加载 | JSON API |
| 关注/取关用户 | `https://www.zhihu.com/api/v4/members/{urlToken}/followers` | POST（关注）/ DELETE（取关） | `x-zse-93`, `x-zse-96`（postSigned/deleteSigned） | `z_c0`, `d_c0` | 无 | `{follower_count:Int}` | 无 | `raiseForStatus` 抛异常 | Web API |
| 拉黑/取消拉黑 | `https://www.zhihu.com/api/v4/members/{urlToken}/actions/block` | POST / DELETE | 同上 | 同上 | 无 | `{}`（仅看 status） | 无 | 同上 | Web API |
| 用户回答列表 | `https://www.zhihu.com/api/v4/members/{urlToken}/answers?sort_by=voteups\|created` | GET | 同上签名；`include` 参数 | 同上 | 无 | `data:List<Answer>`、`paging` | `paging.next` | 待确认 | Web API |
| 用户文章列表 | `https://www.zhihu.com/api/v4/members/{urlToken}/articles?sort_by=created\|voteups` | GET | 同上 | 同上 | 无 | `data:List<Article>`、`paging` | 同上 | 待确认 | Web API |
| 用户动态 | `https://www.zhihu.com/api/v3/moments/{urlToken}/activities` | GET | 同上 | 同上 | 无 | Feed 列表 | 同上 | 待确认 | Web API |
| 用户收藏夹列表 | `https://www.zhihu.com/api/v4/members/{urlToken}/favlists` | GET | 同上 | 同上 | 无 | `data:List<Collection>`、`paging` | 同上 | 待确认 | Web API |
| 用户提问列表 | `https://www.zhihu.com/api/v4/members/{urlToken}/questions` | GET | 同上 | 同上 | 无 | `data:List<Question>`、`paging` | 同上 | 待确认 | Web API |
| 用户想法列表 | `https://www.zhihu.com/api/v4/v2/pins/{urlToken}/moments` | GET | 同上 | 同上 | 无 | `data:List<Pin>`、`paging` | 同上 | 待确认 | Web API |
| 用户专栏贡献 | `https://www.zhihu.com/api/v4/members/{urlToken}/column-contributions` | GET | 同上 | 同上 | 无 | `data:List<Column>`、`paging` | 同上 | 待确认 | Web API |
| 粉丝列表 | `https://api.zhihu.com/people/{id}/followers` | GET | 同上 | 同上 | 无 | `data:List<People>`、`paging` | 同上 | 待确认 | JSON API（旧 API，因签名 bug 临时回退） |
| 关注的人列表 | `https://www.zhihu.com/api/v4/members/{urlToken}/followees` | GET | 同上 | 同上 | 无 | 同上 | 同上 | 待确认 | Web API |
| 关注的专栏 | `https://www.zhihu.com/api/v4/members/{urlToken}/following-columns` | GET | 同上 | 同上 | 无 | `data:List<Column>`、`paging` | 同上 | 待确认 | Web API |
| 关注的话题 | `https://www.zhihu.com/api/v4/members/{urlToken}/following-topic-contributions` | GET | 同上 | 同上 | 无 | `data:List<FollowedTopic>`、`paging` | 同上 | 待确认 | Web API |
| 关注的问题 | `https://www.zhihu.com/api/v4/members/{urlToken}/following-questions` | GET | 同上 | 同上 | 无 | `data:List<FollowedQuestion>`、`paging` | 同上 | 待确认 | Web API |
| 关注的收藏夹 | `https://www.zhihu.com/api/v4/members/{urlToken}/following-favlists` | GET | 同上 | 同上 | 无 | `data:List<Collection>`、`paging` | 同上 | 待确认 | Web API |
| 关注 feed | `https://www.zhihu.com/api/v3/moments?limit=10&desktop=true` | GET | 同上 | 同上 | 无 | Feed 列表 | `paging.next` | 待确认 | Web API |
| 关注推荐 feed | `https://api.zhihu.com/moments_v3?feed_type=recommend` | GET | 同上 | 同上 | 无 | Feed 列表 | 同上 | 待确认 | JSON API |
| 最近活跃关注用户 | `https://api.zhihu.com/moments/recent?type=raw` | GET | 同上 | 同上 | 无 | `data:List<{actor:{id,urlToken,name,avatarUrl},unreadCount:Int}>` | 无 | 失败 → `errorMessage="加载关注动态失败"` | JSON API |

> 通用错误码：HTTP 401 → `executeZhihuAuthenticatedRequest` 触发 `ZhihuCredentialRefresher.refreshZhihuToken`，10 秒节流；刷新后重试一次。HTTP 204 → `fetchZhihuAuthenticatedJson` 返回 null。其余非 2xx 由各调用方处理。

## 4. 点赞机制

**接口差异（POST/DELETE/PUT）：**
- **回答点赞**：`POST /api/v4/answers/{id}/voters`，请求体 `{"type":"up"|"down"|"neutral"}`，支持踩（down）和中立（neutral）。响应仅返回 `voteup_count`。
- **文章点赞**：`POST /api/v4/articles/{id}/voters`，请求体 `{"voting":1|0}`，**仅支持赞（1）和取消（0），不支持踩**。
- **评论点赞**：`POST /api/v4/comments/{commentId}/like`（点赞），`DELETE /api/v4/comments/{commentId}/like`（取消点赞）。**注意是 v4 `comments` 而非 v5 `comment_v5`**。无请求体。
- **取消回答/文章点赞**：复用同一 endpoint，传 `neutral`（回答）或 `0`（文章），**不是 DELETE 方法**。

**voters 接口结构（`ZhihuVotersResponse`）：**
```
{
  "paging": {"page":Int,"is_end":Boolean,"is_start":Boolean,"previous":String?,"totals":Int,"next":String,"prev":String?},
  "data": [{"id":String,"name":String,"avatarUrl":String,"urlToken":String,"headline":String,"gender":Int,...}]
}
```
- `data` 元素类型为 `DataHolder.Author`，含 `id/avatarUrl/avatarUrlTemplate/gender/headline/name/urlToken/badgeV2/followerCount/isFollowed/isBlocked/isFollowing` 等。
- 仅回答有 upvoters 列表，文章不加载（`ArticleViewModel.loadMoreVoters` 中 `if (article.type != ArticleType.Answer) return`）。

**登录态差异：**
- 点赞/踩必须 `z_c0` 登录 Cookie；匿名触发 401 自动刷新流程。
- upvoters 列表匿名也可请求（仅需 `d_c0` 用于签名），但完整字段可能受限（待确认）。

**签名要求：**
- 所有 voters POST 走 `postSigned` → `signZhihuFetchRequest`，附加头：`x-zse-93: 101_3_3.0`、`x-zse-96: 2.0_<encrypt(md5(zse93+pathname+dc0+body))>`、`x-requested-with: fetch`。
- 签名输入包含请求体（对 POST/DELETE），对 GET 不含 body。
- `dc0` 来自 `cookies["d_c0"]`，若为空则**跳过签名**。

**回答认可文案：**
- `GET /api/v4/answers/{id}/relationship?desktop=true` 返回 `{type,text}`，`text` 用于 `votersSocialText` 显示（如「XX 也赞同了该回答」）。

## 5. 收藏机制

**收藏夹列表：**
- 用户级：`GET /api/v4/people/{urlToken}/collections`（`CollectionsViewModel`，分页）。
- 内容级（当前内容被哪些收藏夹收录）：`GET /api.zhihu.com/collections/contents/{contentType}/{id}?limit=50`（`ArticleViewModel.loadCollections`），返回 `CollectionResponse{data,paging}`。

**收藏/取消收藏操作（batch）：**
- `PUT https://api.zhihu.com/collections/contents/{contentType}/{id}`
- 请求体为 **form-urlencoded**：`add_collections={id}` 或 `remove_collections={id}`（注意是下划线 key）。
- `contentType` 取值：`answer` 或 `article`。
- **支持一次操作多个收藏夹**：理论上可传 `add_collections=id1,id2`（待确认实际服务端是否支持多值），但当前代码每次只传一个 id。
- **未走 postSigned 签名**，直接 `httpClient.put`，仅依赖 Cookie。
- 成功后重新拉取 `loadCollections` 刷新列表。

**新建收藏夹：**
- `POST https://www.zhihu.com/api/v4/collections`（注意是 `www.zhihu.com` 而非 `api.zhihu.com`）
- JSON 请求体：`{"title":String,"description":String,"is_public":Boolean}`
- 走 `postSigned` 签名。

**收藏内容分页：**
- `GET /api/v4/collections/{id}/items`（`CollectionContentViewModel`）。
- 响应 `data:List<CollectionItem{created:String,content:Feed.Target}>`，`content` 是 sealed class（AnswerTarget/ArticleTarget/QuestionTarget 等）。
- `CollectionContentViewModel.ensureAllCollectionItemsLoaded` 用于导出时遍历全部分页，通过 `hasPagingProgress` 检测分页是否推进，防止死循环。

**收藏夹元信息：**
- `GET /api/v4/collections/{id}` 返回 `{"collection":Collection}`（注意外层 key）。
- `Collection` 字段：`id,isFavorited,title,isPublic,description,followerCount,answerCount,itemCount,likeCount,viewCount,commentCount,isFollowing,isLiking,createdTime,updatedTime,creator,isDefault`。

**收藏夹导出：**
- `CollectionContentViewModel.exportAllToHtmlZip` 将全部条目打包为 HTML ZIP，含 `includeImages` 开关，进度通过 `CollectionHtmlExportDialogState` 暴露。

## 6. 评论机制

**接口版本：comment_v5 vs v4：**
- 评论列表与发表走 **`comment_v5`**（`/api/v4/comment_v5/...`）。
- 评论点赞/取消点赞走 **v4 `comments`**（`/api/v4/comments/{id}/like`）—— **这是历史遗留，需特别注意**。

**根评论 vs 子评论 vs 楼中楼：**
- **根评论**：`GET /api/v4/comment_v5/{contentType}s/{id}/root_comment?order_by=score|ts`，`contentType` ∈ {answers, articles, pins, questions}，segment 类型为 `{contentType}s/{contentId}/segment/root_comment?segment_id={segmentId}&limit=20&offset=`。
- **子评论（楼中楼）**：`GET /api/v4/comment_v5/comment/{commentId}/child_comment`。
- 根评论响应中的 `Comment.childComments` 已内嵌部分子评论，UI 直接展示；点击「查看全部回复」才拉取完整子评论列表。
- `ChildCommentViewModel` 注释明确：**不按正常 VM 生命周期管理，不要使用 viewModel() 创建**。

**评论排序：**
- `CommentSortOrder.SCORE` → `order_by=score`（按热度，默认）
- `CommentSortOrder.TIME` → `order_by=ts`（按时间）
- 切换排序触发 `refresh` 重新拉取。

**点赞评论：**
- 点赞：`POST /api/v4/comments/{commentId}/like`（无 body）。
- 取消：`DELETE /api/v4/comments/{commentId}/like`。
- 走 `postSigned`/`deleteSigned`，加 x-zse 签名。
- 成功后由调用方 `onSuccess` 回调更新本地 `Comment.liked` 和 `likeCount`。

**回复评论：**
- 根评论回复：`POST /api/v4/comment_v5/{contentType}s/{id}/comment`，body `{"content":"<p>...</p>","reply_comment_id":String?}`。
- 子评论回复：使用父级 article 的 `submitCommentUrl`，body 强制带 `reply_comment_id`。
- 内容被 HTML 转义（`escapeCommentHtml`：`&→&amp;`、`<→&lt;` 等），并包裹 `<p>...</p>`。
- 成功响应直接是新的 `Comment` 对象，被插入到 `allData[0]`。

**评论数据结构（`DataHolder.Comment`）：**
- 关键字段：`id,type,resourceType,url,content,createdTime,isDelete,collapsed,reviewing,liked,likeCount,disliked,dislikeCount,isAuthor,isAuthorTop,canCollapse,canShare,canUnfold,canTruncate,canMore,author,replyToAuthor,commentTag,childCommentCount,childCommentNextOffset,childComments,isVisibleOnlyToMyself`。
- `Author` 子结构：`id,urlToken,name,avatarUrl,avatarUrlTemplate,isOrg,type,url,userType,headline,gender,isAdvertiser,badgeV2,exposedMedal,vipInfo,levelInfo,kvipInfo`。

**屏蔽过滤：**
- `BaseCommentViewModel.filterBlockedComments` 根据 `ContentBlocklistEnvironment.blockedUserIds()` 过滤根评论与内嵌子评论。

**ZhPlus 作者评论区策略：**
- 当 `isZhPlusAuthorContent=true` 时，首次打开评论区弹出一次性确认对话框（`ZH_PLUS_AUTHOR_COMMENT_POLICY_DIALOG_TAG`），要求用户承认「不通过知乎提交 Bug 反馈」。
- 确认状态持久化到 `SharedPreferences`（key=`zh_plus_author_comment_policy_acknowledged`），后续不再展示。

## 7. 个人页

**自己/他人个人页差异：**
- 入口统一为 `PeopleScreen(person: Person)`，不区分自己/他人。
- 差异由后端返回的 `isFollowing`/`isBlocking`/`isFollowed` 等关系字段决定 UI。
- 「关注订阅」tab（第 10 个）含「我订阅的专栏/关注的话题/关注的问题/关注的收藏夹」，对他人也可访问（待确认服务端是否限制）。
- 头部统计项（回答/文章/粉丝/关注）点击可跳到对应 tab。

**profile 字段（`DataHolder.People`）：**
- 基础：`id,urlToken,name,avatarUrl,avatarUrlTemplate,isOrg,type,url,userType,headline,headlineRendered,gender,isAdvertiser,ipInfo,vipInfo,kvipInfo,allowMessage`。
- 关系：`isFollowing,isFollowed,isBlocking`。
- 统计：`followerCount,followingCount,answerCount,articlesCount`。
- 认证：`badgeV2`（含 `injectZhPlusAuthorBadge` 注入逻辑）、`availableMedalsCount,orgVerifyStatus,isRealname,hasApplyingColumn`。
- 社交：`socialMedias:List<SocialMedia{icon,title,link,modules:[{title,value}]}>`（仅 `/profile/detail` 端点返回）。

**profile URL 规则（`peopleProfileUrl`）：**
- 优先用 `urlToken`：`https://api.zhihu.com/people/{urlToken}`。
- `urlToken` 为空时回退到 `id`
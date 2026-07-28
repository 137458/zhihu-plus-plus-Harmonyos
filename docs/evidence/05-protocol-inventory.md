# 接口汇总清单

> 本文档汇总 01-04 证据文档中提到的所有知乎接口，按功能域分类，每条接口一行。所有字段均来自 01-04 源文档原文；源文档中标注「待确认」的字段在本表保持「待确认」，不做补编。
>
> **字段约定**：
> - **zse 签名**：是否需要 `x-zse-93` / `x-zse-96`（Web 签名）头。✓=需要，✗=不需要，? = 待确认。
> - **登录 Cookie**：是否需要 `z_c0` 登录态 Cookie。✓=必须登录，○=可匿名但需 `d_c0` 用于签名，✗=无需登录，? = 待确认。
> - **协议类型**：见文末「协议类型说明」。
>
> **协议类型说明**：
> - **Web JSON API**：`www.zhihu.com/api/...` 走 Web 端，多数带 `x-zse-93/96` 签名
> - **移动 JSON API**：`api.zhihu.com/...` 走移动端，使用 `x-zse-93: 101_1_1.0` + Android 专属 headers + `Authorization: bearer`
> - **JSON API**：未明确分类的 `api.zhihu.com` / `www.zhihu.com/api/v4` GET 接口
> - **Web HTML**：返回 HTML 页面（用于种 cookie / 风控页 / WebView 渲染）
> - **静态资源**：字体、图片等二进制资源
> - **Web API（SSE）**：Server-Sent Events 流式接口

## 1. 鉴权与会话

来源：[01-auth-and-session.md](./01-auth-and-session.md) §3

| 用途 | 方法 | URL / 路径 | zse 签名 | 登录 Cookie | 请求体字段 | 关键响应字段 | 来源 |
|---|---|---|---|---|---|---|---|
| 当前账号信息 | GET | `https://www.zhihu.com/api/v4/me` | ? | ✓（`z_c0`/`d_c0`/`_xsrf`） | 无 | `id`、`name`、`url_token`、`user_type`、`avatar_url` | 01 §3 |
| Token 中转 | POST | `https://www.zhihu.com/api/account/prod/token/refresh` | ✗ | ✓（含 `z_c0`） | 无（依赖 cookie 中的旧 token） | `refresh_token: String` | 01 §3 |
| OAuth 刷新 | POST | `https://www.zhihu.com/api/v3/oauth/sign_in` | ✗（body 走 `ZseSigner.encryptZseV4` 加密） | ✓（必须有 `z_c0`） | `ZseSigner.encryptZseV4(formData)`，加密前字段：`client_id`、`grant_type=refresh_token`、`timestamp`、`source=com.zhihu.web`、`signature=HMAC-SHA1`、`refresh_token` | `access_token: String` | 01 §3 |
| 登录预取（HTML） | GET | `https://www.zhihu.com/signin?next=%2F` | ✗ | ✗（自动带） | 无 | HTML 页面（仅为种 cookie） | 01 §3 |
| UDID 注册 | POST | `https://www.zhihu.com/udid` | ✗ | ○（自动带） | `"{}"` | 待确认 | 01 §3 |
| 验证码元信息 | GET | `https://www.zhihu.com/api/v3/oauth/captcha/v2?type=captcha_sign_in` | ✗ | ○（自动带） | 无 | 待确认（可能含 `show_captcha`、`captcha_url`） | 01 §3 |
| 申请二维码 | POST | `https://www.zhihu.com/api/v3/account/api/login/qrcode` | ✗（需 `x-xsrftoken`） | ○（自动带） | `"{}"` | `expires_at`、`link`、`token` / `qrcode_token` | 01 §3 |
| 二维码轮询 | GET | `https://www.zhihu.com/api/v3/account/api/login/qrcode/{token}/scan_info` | ✓（`x-zse-93: 101_3_3.0`，需 `x-xsrftoken`） | ○（自动带） | 无 | `status`、`cookie`、`cookies`、`z_c0`、`user_id`、`access_token`、`success`、`logged_in`、`login_status`、`error: { need_login, redirect, code, message }` | 01 §3 |
| 风控页面 | GET（WebView） | `https://www.zhihu.com/account/risk_control/` 或 `error.redirect` | ✗ | WebView `CookieManager` 注入 | 无 | HTML（由 WebView 处理） | 01 §3 |
| 身份列表 | GET | `https://api.zhihu.com/people/account/list` | ✓（`x-zse-93: 101_1_1.0`，移动签名） | ✓（含 `z_c0`，`Authorization: bearer {mobileAccessToken}`） | 无 | `data: [{ id, url_token, name, avatar_url, is_active, can_create_sub_account, account_type, sub_account_control_status }]` | 01 §3 |
| 创建子账号 | POST | `https://api.zhihu.com/account/sub/register` | ✓（移动签名） | ✓（自动带） | 无（不发送 body） | `uid`、`user_id`、`token_type: "bearer"`、`access_token`、`refresh_token`、`expires_in`、`cookie: { z_c0, q_c0, ... }`、`expires_at` | 01 §3 |
| 切换账号 | POST | `https://api.zhihu.com/account/switch` | ✓（移动签名） | ✓（自动带） | `{"target_user_id": "{userId}"}` | 同创建子账号 | 01 §3 |
| 新身份验证 | GET | `https://api.zhihu.com/people/self` | ✓（移动签名，`Authorization` 用新签发的 token） | 用新 cookies 创建临时 client | 无 | `id`、`url_token`、`name`、`user_type`、`avatar_url`、`can_create_sub_account`、`account_type` | 01 §3 |

**说明**：
- `/api/v4/me` 是否带 zse 签名头在 01 §3 表中未显式列出，标记「待确认」。该接口由 `fetchVerifiedZhihuAccount` / `fetchVerifiedZhihuSession` 调用，HTTP 200 视为登录态，401 触发刷新。
- Token 中转 / OAuth 刷新 / 二维码申请 / 风控页面均不带 zse93/96 签名；OAuth 刷新的请求体通过 `ZseSigner.encryptZseV4` 自定义加密（与 `x-zse-96` 后半段同算法），但不写 `x-zse-93` 头。
- 二维码轮询是 01 §3 中唯一显式声明 `x-zse-93: 101_3_3.0` 的鉴权类接口。

## 2. 首页与推荐

来源：[02-home-and-search.md](./02-home-and-search.md) §3、§5

| 用途 | 方法 | URL / 路径 | zse 签名 | 登录 Cookie | 请求体字段 | 关键响应字段 | 来源 |
|---|---|---|---|---|---|---|---|
| Web 首页推荐 | GET | `https://api.zhihu.com/topstory/recommend`（query `include=data[*].content,excerpt,headline,target.author.badge_v2`） | ✓（`d_c0` 缺失则跳过） | ○（`allowGuestAccess=true`） | 无 | `data: []` Feed 数组、`paging: { next, is_end, ... }` | 02 §3 |
| Android 首页推荐 | GET | `https://api.zhihu.com/topstory/recommend` | ✗（用 Android UA + `x-api-version: 3.1.8` + `x-app-version: 10.61.0` + `x-app-za`） | ○（`loginForRecommendation=true` 时携带） | 无 | `data: []` `ComponentCard` 数组、`paging` | 02 §3 |
| 混合首页推荐 | GET | 同 Web + Android | 同上 | 同上 | 无 | 合并去重 | 02 §3、02 §5 |
| 本地推荐 | — | 无（`initialUrl = error(...)`，依赖 `LocalRecommendationEngine`） | — | — | — | — | 02 §3、02 §5 |

**说明**：
- Web / Android / 混合三种模式共用同一 URL，差异在请求头与解析逻辑。
- 默认推荐模式为 `MIXED`（02 §5），并发执行 Android + Web 两路 fetch。
- 每种模式有独立启动缓存文件 `home_feed_startup_cache_{key}.json`，上限 10 条。

## 3. 搜索

来源：[02-home-and-search.md](./02-home-and-search.md) §3、§7

| 用途 | 方法 | URL / 路径 | zse 签名 | 登录 Cookie | 请求体字段 | 关键响应字段 | 来源 |
|---|---|---|---|---|---|---|---|
| 搜索 | GET | `https://www.zhihu.com/api/v4/search_v3?gk_version=gz-gaokao&t=general&q=<enc>&correction=1&offset=0&limit=20&search_source=Normal\|Filter&show_all_topics=0[&vertical=<answer\|article\|zvideo>&vertical_info=0,0,0,0,0,0,0,0,0,0,0,0][&sort=created_time\|upvoted_count][&time_interval=a_day\|a_week\|...][&restricted_scene=member&restricted_field=member_hash_id&restricted_value=<hash>&filter_fields=&lc_idx=0]` | ✓ | ✓（`allowGuestAccess=false`，必须登录） | 无 | `data: []` SearchResult 数组（每项 `{type, id, object, highlight, index, hit_labels}`）、`paging` | 02 §3、02 §7 |
| 热搜 | GET | `https://www.zhihu.com/api/v4/search/hot_search` | ✓ | ✓（`allowGuestAccess=false`） | 无 | `hot_search_queries: [{ query, hot_show, label }]`（取前 15 条） | 02 §3、02 §7 |
| 搜索建议 | — | — | — | — | — | — | 02 §7 |

**说明**：
- 搜索结果分页用 `paging.next`，首次 `limit=20&offset=0`。
- 搜索建议在 Android 工程中**未实现**（02 §7），无对应接口。
- 搜索结果类型 `search_result` / `koc_box` / `knowledge_ad`，后两者 `toFeed()` 返回 null 不显示。
- member 限定搜索隐藏热搜与全局历史，且不写入历史。
- 搜索历史为本地 SharedPreferences（key `searchHistoryQueries`，上限 20），无网络接口。

## 4. 内容详情

来源：[03-content-detail.md](./03-content-detail.md) §3

| 用途 | 方法 | URL / 路径 | zse 签名 | 登录 Cookie | 请求体字段 | 关键响应字段 | 来源 |
|---|---|---|---|---|---|---|---|
| 问题详情 | GET | `https://www.zhihu.com/api/v4/questions/{questionId}` | ? | 全量 zhihu cookie（含 `d_c0`） | 无 | `type,id,title,questionType,created,updatedTime,url,answer_count,visit_count,comment_count,follower_count,detail,excerpt,author,relationship.is_following,topics,voteup_count` | 03 §3 |
| 问题回答列表 feeds | GET | `https://www.zhihu.com/api/v4/questions/{questionId}/feeds?limit=20[&order={default\|updated}]` | ? | 同上 | 无 | `data[]` Feed 列表、`paging.{next,previous}` | 03 §3 |
| 关注问题 | POST / DELETE | `https://www.zhihu.com/api/v4/questions/{questionId}/followers` | ✓（`postSigned` / `deleteSigned`） | 需 `d_c0` | 无 | `{}`（mock） | 03 §3 |
| 回答详情 | GET | `https://www.zhihu.com/api/v4/answers/{answerId}` | ? | 全量 zhihu cookie | 无 | `.settings,content,editable_content,paid_info,can_comment,excerpt,thanks_count,voteup_count,comment_count,visited_count,attachment,reaction,ip_info,pagination_info,endorsements,question.topics,question.author,reaction.relation.voting,author.badge_v2,settings.table_of_contents.enabled` | 03 §3 |
| 文章详情 | GET | `https://www.zhihu.com/api/v4/articles/{articleId}` | ? | 全量 zhihu cookie | 无 | `content,topics,paid_info,can_comment,excerpt,thanks_count,voteup_count,comment_count,visited_count,relationship,ip_info,relationship.vote,author.badge_v2` | 03 §3 |
| Pin（想法）详情 | GET | `https://www.zhihu.com/api/v4/pins/{pinId}` | ? | 全量 zhihu cookie | 无 | 待确认（解码为 `DataHolder.Pin`） | 03 §3 |
| 回答投票（赞同/反对/中立） | POST | `https://www.zhihu.com/api/v4/answers/{answerId}/voters` | ✓ | ✓ | `{"type":"UP"\|"DOWN"\|"Neutral"}` | `voteup_count` | 03 §3、04 §3、04 §4 |
| 文章投票（仅赞同/取消） | POST | `https://www.zhihu.com/api/v4/articles/{articleId}/voters` | ✓ | ✓ | `{"voting":1\|0}` | `voteup_count` | 03 §3、04 §3、04 §4 |
| 回答赞同者分页 | GET | `https://www.zhihu.com/api/v4/answers/{answerId}/upvoters?limit=10&offset=0` | ✓（04 §3 明示；03 §3 未显式列出） | ○（匿名也可，需 `d_c0` 签名） | 无 | `data[].author`、`paging.{totals,next,is_end}` | 03 §3、04 §3 |
| 回答关系背书 | GET | `https://www.zhihu.com/api/v4/answers/{answerId}/relationship?desktop=true` | ✓（04 §3 明示；03 §3 未显式列出） | 同上 | 无 | `{type,text}`（`AnswerRelationshipEndorsement`） | 03 §3、04 §3 |
| 收藏内容（添加/移除） | PUT | `https://api.zhihu.com/collections/contents/{answer\|article}/{id}` | ✗（04 §3 明示「未走 postSigned」） | ✓ | `add_collections={id}` 或 `remove_collections={id}`（form-urlencoded） | 仅看 HTTP status | 03 §3、04 §3、04 §5 |
| 收藏列表（内容所在收藏夹） | GET | `https://api.zhihu.com/collections/contents/{answer\|article}/{id}?limit=50` | ?（04 §3 标「待确认」，走 `fetchJson` 应签名） | 同上 | 无 | `data[].id,is_favorited` 等、`paging` | 03 §3、04 §3 |
| 创建收藏夹 | POST | `https://www.zhihu.com/api/v4/collections` | ✓（`postSigned`） | ✓ | `{"title":String,"description":String,"is_public":Boolean}` | 待确认 | 03 §3、04 §3 |
| 收藏夹详情 | GET | `https://www.zhihu.com/api/v4/collections/{id}` | ? | 全量 cookie | 无 | `{collection:Collection}`（注意外层 key） | 04 §3、04 §5 |
| 收藏夹条目分页 | GET | `https://www.zhihu.com/api/v4/collections/{collectionId}/items` | ? | 全量 cookie | 无 | `data[].content`、`paging.next` | 03 §3、04 §3 |
| AI 总结（zhida）SSE | POST | `https://www.zhihu.com/ai_ingress/stream/completion` | ✗（需 `x-xsrftoken`，无 zse 签名） | ✓ | `serializeZhidaSummaryRequest(...)`（含 `contentId,contentType,title`） | SSE 事件：`answer`(delta/全量)、`error`、`end` | 03 §3 |
| 评论拉取（导出用，根评论） | GET | `https://www.zhihu.com/api/v4/comment_v5/{answers\|articles}/{id}/root_comment?order=score&limit={N}` | ?（03 §3 仅写「UA + include」，未显式说签名） | 全量 cookie | 无 | `data[].content,author,created_time` | 03 §3 |
| LaTeX 字体下载（KaTeX） | GET | `https://registry.npmmirror.com/katex/0.16.11/files/dist/fonts/{KaTeX_*.ttf}` | ✗ | ✗ | 无 | 二进制 TTF | 03 §3 |
| LaTeX 字体下载（Latin Modern Math） | GET | `https://mirrors.ustc.edu.cn/CTAN/fonts/lm-math/opentype/latinmodern-math.otf`（fallback: `https://mirrors.tuna.tsinghua.edu.cn/...`） | ✗ | ✗ | 无 | 二进制 OTF（验证 `OTTO` magic bytes） | 03 §3 |
| 知乎公式图 | GET | `https://www.zhihu.com/equation?tex={URL_ENCODED_TEX}` | ✗ | 全量 cookie | 无 | SVG/PNG（知乎服务端渲染） | 03 §3 |

**说明**：
- 03 §3 中多个 GET 详情接口未显式声明 zse 签名头，标记「待确认」。02 §3 通用说明指出「所有走 `fetchJson` / `postSigned` / `deleteSigned` 的接口均签名」，但 03 §3 接口表对这些 GET 详情接口未列出 `x-zse-93/96` 头，存在文档间不一致。
- 评论相关接口在 03 §3 仅列「导出用」一条；完整评论接口见 §6 互动。
- deeplink 解析规则见 03 §4，覆盖 `zhihu://`、`www.zhihu.com/...`、`zhuanlan.zhihu.com/p/...` 等多种形态。

## 5. 互动（点赞 / 收藏 / 评论）

来源：[04-interaction-and-profile.md](./04-interaction-and-profile.md) §3、§4、§5、§6

> 点赞 / 收藏相关接口与 §4 内容详情有重叠，本节侧重 04 §3 的明细。

| 用途 | 方法 | URL / 路径 | zse 签名 | 登录 Cookie | 请求体字段 | 关键响应字段 | 来源 |
|---|---|---|---|---|---|---|---|
| 赞同/反对回答 | POST | `https://www.zhihu.com/api/v4/answers/{id}/voters` | ✓ | ✓（`z_c0`, `d_c0`） | `{"type":"up"\|"down"\|"neutral"}` | `voteup_count:Int` | 04 §3、04 §4 |
| 赞同文章 | POST | `https://www.zhihu.com/api/v4/articles/{id}/voters` | ✓ | 同上 | `{"voting":1\|0}`（1=赞，0=取消，无 down） | `voteup_count:Int` | 04 §3、04 §4 |
| 回答赞同者列表 | GET | `https://www.zhihu.com/api/v4/answers/{id}/upvoters?limit=10&offset=0` | ✓ | ○（`d_c0` 匿名也可） | 无 | `data:List<Author>`、`paging:{next,is_end,totals}` | 04 §3、04 §4 |
| 回答关系（认可文案） | GET | `https://www.zhihu.com/api/v4/answers/{id}/relationship?desktop=true` | ✓ | 同上 | 无 | `{type,text}` | 04 §3、04 §4 |
| 内容所在收藏夹列表 | GET | `https://api.zhihu.com/collections/contents/{contentType}/{id}?limit=50` | ?（04 §3 标「待确认」） | 同上 | 无 | `data:List<Collection>`、`paging` | 04 §3、04 §5 |
| 收藏/取消收藏内容 | PUT | `https://api.zhihu.com/collections/contents/{contentType}/{id}` | ✗（04 §3 明示「未走 postSigned」） | ✓ | `add_collections={id}` 或 `remove_collections={id}`（form-urlencoded） | 仅看 HTTP status | 04 §3、04 §5 |
| 新建收藏夹 | POST | `https://www.zhihu.com/api/v4/collections` | ✓（`postSigned`） | ✓ | `{"title":String,"description":String,"is_public":Boolean}` | 待确认 | 04 §3、04 §5 |
| 用户收藏夹列表 | GET | `https://www.zhihu.com/api/v4/people/{urlToken}/collections` | ✓ | 同上 | 无 | `data:List<Collection>`、`paging` | 04 §3、04 §5 |
| 收藏夹详情 | GET | `https://www.zhihu.com/api/v4/collections/{id}` | ✓ | 同上 | 无 | `{collection:Collection}` | 04 §3、04 §5 |
| 收藏夹条目列表 | GET | `https://www.zhihu.com/api/v4/collections/{id}/items` | ✓ | 同上 | 无 | `data:List<CollectionItem{created,content:Feed.Target}>`、`paging` | 04 §3、04 §5 |
| 根评论列表 | GET | `https://www.zhihu.com/api/v4/comment_v5/{contentType}s/{id}/root_comment?order_by=score\|ts`（`contentType` ∈ {answers, articles, pins, questions}；segment 类型为 `{contentType}s/{contentId}/segment/root_comment?segment_id={segmentId}&limit=20&offset=`） | ✓ | 同上 | 无 | `data:List<Comment>`、`paging` | 04 §3、04 §6 |
| 子评论列表 | GET | `https://www.zhihu.com/api/v4/comment_v5/comment/{commentId}/child_comment` | ✓ | 同上 | 无 | 同根评论 | 04 §3、04 §6 |
| 发表评论 | POST | `https://www.zhihu.com/api/v4/comment_v5/{answers\|articles\|pins\|questions\|{contentType}s}/{id}/comment`（segment 附加 `?segment_id={segmentId}`） | ✓ | ✓（`z_c0`, `d_c0`） | `{"content":"<p>...</p>","reply_comment_id":String?}`（内容经 `escapeCommentHtml` 转义并包裹 `<p>`） | 返回新 `Comment` 对象 | 04 §3、04 §6 |
| 点赞评论 | POST | `https://www.zhihu.com/api/v4/comments/{commentId}/like` | ✓（`postSigned`） | ✓（`z_c0`, `d_c0`） | 无 | 仅看 HTTP status | 04 §3、04 §6 |
| 取消点赞评论 | DELETE | `https://www.zhihu.com/api/v4/comments/{commentId}/like` | ✓（`deleteSigned`） | 同上 | 无 | 同上 | 04 §3、04 §6 |

**说明**：
- 评论列表与发表走 **`comment_v5`**（`/api/v4/comment_v5/...`）；评论点赞/取消点赞走 **v4 `comments`**（`/api/v4/comments/{id}/like`）—— 04 §6 注明「历史遗留，需特别注意」。
- 取消回答/文章点赞**复用同一 endpoint**传 `neutral`（回答）或 `0`（文章），**不是 DELETE 方法**。
- 收藏内容 PUT 接口**未走 postSigned 签名**，仅依赖 Cookie。
- 评论 `childComments` 已内嵌在根评论响应中，UI 直接展示；点击「查看全部回复」才拉取完整子评论。

## 6. 个人页

来源：[04-interaction-and-profile.md](./04-interaction-and-profile.md) §3、§7

| 用途 | 方法 | URL / 路径 | zse 签名 | 登录 Cookie | 请求体字段 | 关键响应字段 | 来源 |
|---|---|---|---|---|---|---|---|
| 个人页资料 | GET | `https://api.zhihu.com/people/{identifier}`（优先 `urlToken`，空时回退 `id`） | ✓（`fetchJson` 走签名） | ○（`d_c0` 匿名可访问公开字段） | 无 | `People{id,urlToken,name,avatarUrl,headline,gender,isFollowing,isBlocking,followerCount,followingCount,answerCount,articlesCount,badgeV2,...}`；含 `include` 参数 | 04 §3、04 §7 |
| 个人页详情（社交链接） | GET | `https://api.zhihu.com/people/{identifier}/profile/detail` | ✓ | 同上 | 无 | `People{socialMedias:[{title,link,icon,modules:[{title,value}]}]}` | 04 §3、04 §7 |
| 关注 / 取关用户 | POST（关注）/ DELETE（取关） | `https://www.zhihu.com/api/v4/members/{urlToken}/followers` | ✓（`postSigned` / `deleteSigned`） | ✓（`z_c0`, `d_c0`） | 无 | `{follower_count:Int}` | 04 §3 |
| 拉黑 / 取消拉黑 | POST / DELETE | `https://www.zhihu.com/api/v4/members/{urlToken}/actions/block` | ✓ | 同上 | 无 | `{}`（仅看 status） | 04 §3 |
| 用户回答列表 | GET | `https://www.zhihu.com/api/v4/members/{urlToken}/answers?sort_by=voteups\|created` | ✓（含 `include`） | 同上 | 无 | `data:List<Answer>`、`paging` | 04 §3 |
| 用户文章列表 | GET | `https://www.zhihu.com/api/v4/members/{urlToken}/articles?sort_by=created\|voteups` | ✓ | 同上 | 无 | `data:List<Article>`、`paging` | 04 §3 |
| 用户动态 | GET | `https://www.zhihu.com/api/v3/moments/{urlToken}/activities` | ✓ | 同上 | 无 | Feed 列表 | 04 §3 |
| 用户收藏夹列表 | GET | `https://www.zhihu.com/api/v4/members/{urlToken}/favlists` | ✓ | 同上 | 无 | `data:List<Collection>`、`paging` | 04 §3 |
| 用户提问列表 | GET | `https://www.zhihu.com/api/v4/members/{urlToken}/questions` | ✓ | 同上 | 无 | `data:List<Question>`、`paging` | 04 §3 |
| 用户想法列表 | GET | `https://www.zhihu.com/api/v4/v2/pins/{urlToken}/moments` | ✓ | 同上 | 无 | `data:List<Pin>`、`paging` | 04 §3 |
| 用户专栏贡献 | GET | `https://www.zhihu.com/api/v4/members/{urlToken}/column-contributions` | ✓ | 同上 | 无 | `data:List<Column>`、`paging` | 04 §3 |
| 粉丝列表 | GET | `https://api.zhihu.com/people/{id}/followers` | ✓ | 同上 | 无 | `data:List<People>`、`paging` | 04 §3 |
| 关注的人列表 | GET | `https://www.zhihu.com/api/v4/members/{urlToken}/followees` | ✓ | 同上 | 无 | `data:List<People>`、`paging` | 04 §3 |
| 关注的专栏 | GET | `https://www.zhihu.com/api/v4/members/{urlToken}/following-columns` | ✓ | 同上 | 无 | `data:List<Column>`、`paging` | 04 §3 |
| 关注的话题 | GET | `https://www.zhihu.com/api/v4/members/{urlToken}/following-topic-contributions` | ✓ | 同上 | 无 | `data:List<FollowedTopic>`、`paging` | 04 §3 |
| 关注的问题 | GET | `https://www.zhihu.com/api/v4/members/{urlToken}/following-questions` | ✓ | 同上 | 无 | `data:List<FollowedQuestion>`、`paging` | 04 §3 |
| 关注的收藏夹 | GET | `https://www.zhihu.com/api/v4/members/{urlToken}/following-favlists` | ✓ | 同上 | 无 | `data:List<Collection>`、`paging` | 04 §3 |

**说明**：
- 04 §3 标注「粉丝列表」用 `api.zhihu.com` 旧 API 是「因签名 bug 临时回退」，移植时需验证是否仍走旧 API。
- 「关注订阅」tab 对他人是否可访问，04 §7 标注「待确认服务端是否限制」。

## 7. 关注动态

来源：[02-home-and-search.md](./02-home-and-search.md) §3、[04-interaction-and-profile.md](./04-interaction-and-profile.md) §3

| 用途 | 方法 | URL / 路径 | zse 签名 | 登录 Cookie | 请求体字段 | 关键响应字段 | 来源 |
|---|---|---|---|---|---|---|---|
| 关注 feed | GET | `https://www.zhihu.com/api/v3/moments?limit=10&desktop=true` | ✓ | 同 Web 首页 | 无 | Feed 列表、`paging.next` | 02 §3、04 §3 |
| 关注推荐 feed | GET | `https://api.zhihu.com/moments_v3?feed_type=recommend` | ✓ | 同上 | 无 | Feed 列表 | 02 §3、04 §3 |
| 最近活跃关注用户 | GET | `https://api.zhihu.com/moments/recent?type=raw` | ✓ | 同上 | 无 | `data:List<{actor:{id,url_token,name,avatar_url},unread_count}>` | 02 §3、04 §3 |

## 8. 上报

来源：[02-home-and-search.md](./02-home-and-search.md) §3

| 用途 | 方法 | URL / 路径 | zse 签名 | 登录 Cookie | 请求体字段 | 关键响应字段 | 来源 |
|---|---|---|---|---|---|---|---|
| 浏览 touch 上报 | POST（`postSigned`） | `https://www.zhihu.com/lastread/touch` | ✓ | `d_c0` 必须存在 | `formData { append("items", "[[\"answer\",\"<id>\",\"touch\"]]") }`（multipart，items 是 JSON 字符串） | 仅看 HTTP status | 02 §3 |
| 阅读 read 上报 | POST（`postSigned`） | `https://www.zhihu.com/lastread/touch` | ✓ | `d_c0` 必须存在 | `items` = `[["answer","<id>","read"]]`（或 article/pin） | 同上 | 02 §3 |
| 阅读历史加入 | POST（`postSigned`） | `https://www.zhihu.com/api/v4/read_history/add` | ✓ | `d_c0` 必须存在 | `{"content_token":"<token>","content_type":"<answer\|article\|pin>"}` | 待确认 | 02 §3 |

**说明**：
- touch 与 read 上报共用同一 URL `https://www.zhihu.com/lastread/touch`，差异在 `items` 数组第三项（`"touch"` vs `"read"`）。
- `d_c0` cookie 缺失时整体跳过上报（02 §6）。
- 上报失败仅 `Log.e("Browse-Touch", body)`，静默处理。

## 9. 协议类型分布汇总

| 协议类型 | 接口数（去重后） | 主要域名 | 是否签名 |
|---|---|---|---|
| Web JSON API | 30+ | `www.zhihu.com/api/v4`、`www.zhihu.com/api/v3`、`www.zhihu.com/lastread`、`www.zhihu.com/ai_ingress`、`www.zhihu.com/signin`、`www.zhihu.com/udid`、`www.zhihu.com/account/risk_control` | 多数带 zse93/96；少数 PUT 接口不签名 |
| 移动 JSON API | 4 | `api.zhihu.com/people/account/list`、`api.zhihu.com/account/sub/register`、`api.zhihu.com/account/switch`、`api.zhihu.com/people/self` | 带移动签名 `x-zse-93: 101_1_1.0` + `Authorization: bearer` |
| JSON API（`api.zhihu.com`） | 8+ | `api.zhihu.com/topstory/recommend`、`api.zhihu.com/collections/contents/...`、`api.zhihu.com/people/{id}`、`api.zhihu.com/people/{id}/followers`、`api.zhihu.com/people/{id}/profile/detail`、`api.zhihu.com/moments_v3`、`api.zhihu.com/moments/recent` | Web 推荐走 zse 签名；收藏 PUT 不签名；其余 fetchJson 接口签名 |
| Web HTML | 3 | `www.zhihu.com/signin`、`www.zhihu.com/account/risk_control/`、`error.redirect` | 不签名 |
| 静态资源 | 3 | `registry.npmmirror.com`、`mirrors.ustc.edu.cn`、`mirrors.tuna.tsinghua.edu.cn`、`www.zhihu.com/equation` | 不签名 |
| Web API（SSE） | 1 | `www.zhihu.com/ai_ingress/stream/completion` | 不签名（需 `x-xsrftoken`） |

## 10. 跨文档未确认项汇总

> 以下接口字段在 01-04 文档中显式标注「待确认」，移植前需通过抓包或实测确认。

| 接口 | 未确认字段 | 来源 |
|---|---|---|
| `/api/v4/me` | 是否带 zse 签名头 | 01 §3 |
| `/udid` | 响应字段、错误码 | 01 §3 |
| `/api/v3/oauth/captcha/v2` | 响应字段（`show_captcha`、`captcha_url` 是否存在） | 01 §3 |
| `/api/v4/read_history/add` | 响应字段、错误码 | 02 §3 |
| `/api/v4/questions/{id}` | 是否带 zse 签名、错误码 | 03 §3 |
| `/api/v4/questions/{id}/feeds` | 是否带 zse 签名、错误码 | 03 §3 |
| `/api/v4/answers/{id}` | 是否带 zse 签名、错误码 | 03 §3 |
| `/api/v4/articles/{id}` | 是否带 zse 签名、错误码 | 03 §3 |
| `/api/v4/pins/{id}` | 响应字段、是否带 zse 签名、错误码 | 03 §3 |
| `/api/v4/answers/{id}/upvoters` | 03 §3 未显式列签名头（04 §3 明示带签名）；错误码 | 03 §3、04 §3 |
| `/api/v4/answers/{id}/relationship` | 同上 | 03 §3、04 §3 |
| `PUT /collections/contents/{type}/{id}` | 错误码 | 03 §3、04 §3 |
| `GET /collections/contents/{type}/{id}` | 是否带 zse 签名、错误码 | 04 §3 |
| `POST /api/v4/collections` | 响应字段、错误码 | 03 §3、04 §3 |
| `GET /api/v4/collections/{id}` | 是否带 zse 签名、错误码 | 04 §3 |
| `GET /api/v4/collections/{id}/items` | 是否带 zse 签名、错误码 | 03 §3、04 §3 |
| `/comment_v5/.../root_comment`（导出用） | 是否带 zse 签名、错误码 | 03 §3 |
| 各个人页列表接口（answers/articles/favlists/questions 等） | 错误码 | 04 §3 |
| `/api/v4/people/{urlToken}/favlists` 对他人访问 | 服务端是否限制 | 04 §7 |
| 收藏 PUT `add_collections=id1,id2` 多值 | 服务端是否支持 | 04 §5 |

## 11. 协议层关键常量

> 以下常量来自 01-04 文档原文，移植时需在 ArkTS 端等价复现。

| 常量 | 值 | 来源 |
|---|---|---|
| `x-zse-93`（Web） | `101_3_3.0` | 01 §4.1、02 §3、04 §3 |
| `x-zse-93`（移动身份 API） | `101_1_1.0` | 01 §3 |
| `x-zse-83`（OAuth 刷新） | `3_3.0` | 01 §3 |
| `CLIENT_ID` | `c3cef7c66a1843f8b3a9e6a1e3160e20` | 01 §4.3 |
| `CLIENT_SECRET` | `d1b964811afb40118a12068ff74a12f4` | 01 §4.3 |
| `GRANT_TYPE` | `refresh_token` | 01 §4.3 |
| `SOURCE` | `com.zhihu.web` | 01 §4.3 |
| ZseSigner `KEY16` | `059053f7d15e01d7`（UTF-8 字节） | 01 §4.2 |
| ZseSigner `ZB`（S-Box） | 256 字节硬编码 | 01 §4.2 |
| ZseSigner `ZK`（轮密钥） | 32 个 u32 常量 | 01 §4.2 |
| ZseSigner Base64 字母表 | `6fpLRqJO8M/c3jnYxFkUVC4ZIG12SiH=5v0mXDazWBTsuw7QetbKdoPyAl+hN9rgE` | 01 §4.2 |
| 签名拼接格式 | `zse93 + "+" + pathname + "+" + dc0 + "+" + body` | 01 §4.1、02 §3 |
| `x-zse-96` 格式 | `2.0_` + `ZseSigner.encryptZseV4(md5Hex(signSource))` | 01 §4.1、02 §3 |
| Desktop UA | `ZHIHU_DESKTOP_USER_AGENT`（Chrome 145） | 01 §3 |
| Web 推荐 UA | `DEFAULT_ZHIHU_USER_AGENT`（Linux Ubuntu UA） | 02 §3 |
| Android 推荐 UA | `com.zhihu.android/Futureve/10.61.0 ...` | 02 §3 |
| 移动身份 UA | `ZHIHU_ANDROID_IDENTITY_USER_AGENT` | 01 §3 |
| 移动身份 `x-api-version` | `3.0.93` | 01 §3 |
| 移动身份 `x-app-version` | `11.2.0` | 01 §3 |
| 移动身份 `x-app-build` | `release` | 01 §3 |
| 移动身份 `x-app-bundleid` | `com.zhihu.android` | 01 §3 |
| 移动身份 `x-app-flavor` | `zhihuwap64` | 01 §3 |
| Android 推荐 `x-api-version` | `3.1.8` | 02 §3 |
| Android 推荐 `x-app-version` | `10.61.0` | 02 §3 |
| 搜索 `vertical_info` 常量 | `0,0,0,0,0,0,0,0,0,0,0,0`（12 个 0） | 02 §7 |
| 搜索 `gk_version` | `gz-gaokao` | 02 §7 |
| 搜索 `t` | `general` | 02 §7 |
| 搜索 `correction` | `1` | 02 §7 |
| 搜索 `show_all_topics` | `0` | 02 §7 |
| 搜索历史上限 | 20（`SEARCH_HISTORY_MAX_SIZE`） | 02 §7 |
| 首页启动缓存条数上限 | 10 | 02 §5 |
| ContentDetailCache 容量 / TTL | 100 / 10 分钟 | 03 §1 |
| 401 刷新节流 | 10 秒 | 01 §6 |
| 主动 token 刷新间隔 | ≥ 1 天 | 01 §6 |

## 12. 参考实现位置

> Android 参考工程位置：`HarmonyApp/zhihu-plus-plus/`（独立 git 仓库，已被 `.gitignore` 忽略）。当前调研环境该目录不可访问，下列路径来自 01-04 文档原文记录。

| 模块 | 文件路径 | 来源 |
|---|---|---|
| HTTP 客户端工厂 | `shared/src/commonMain/.../shared/data/ZhihuDataTypes.kt`（`installZhihuCommonClientConfig`） | 01 §1 |
| Cookie 存储 | `shared/src/commonMain/.../shared/data/ZhihuApiClients.kt`（`ZhihuCookieStorage`） | 01 §1 |
| 已认证请求调度 | `shared/src/commonMain/.../shared/data/ZhihuApiClients.kt`（`executeZhihuAuthenticatedRequest`、`fetchZhihuAuthenticatedJson`） | 01 §1 |
| 会话验证 | `shared/src/commonMain/.../shared/data/ZhihuDataTypes.kt`（`fetchVerifiedZhihuAccount`、`fetchVerifiedZhihuSession`） | 01 §1 |
| Web 签名 zse93/zse96 | `shared/src/commonMain/.../shared/util/ZhihuFetchSignature.kt` | 01 §1、01 §4.1 |
| ZSE-V4 加密 | `shared/src/commonMain/.../shared/util/ZseSigner.kt` | 01 §1、01 §4.2 |
| Token 刷新 | `shared/src/commonMain/.../util/ZhihuCredentialRefresher.kt` | 01 §1、01 §4.3 |
| 二维码登录 | `shared/src/commonMain/.../shared/login/QrLogin.kt` | 01 §1 |
| 移动身份切换 | `shared/src/commonMain/.../shared/account/ZhihuIdentityClient.kt` | 01 §1、01 §7 |
| Web 首页 ViewModel | `shared/src/commonMain/.../viewmodel/feed/HomeFeedViewModel.kt` | 02 §1 |
| Android 首页 ViewModel | `shared/src/commonMain/.../viewmodel/za/AndroidHomeFeedViewModel.kt` | 02 §1 |
| 混合首页 ViewModel | `shared/src/commonMain/.../viewmodel/za/MixedHomeFeedViewModel.kt` | 02 §1 |
| 本地推荐 ViewModel | `shared/src/commonMain/.../viewmodel/local/LocalHomeFeedViewModel.kt` | 02 §1 |
| 搜索 ViewModel | `shared/src/commonMain/.../viewmodel/feed/SearchViewModel.kt` | 02 §1 |
| 问题详情 ViewModel | `shared/.../viewmodel/feed/QuestionFeedViewModel.kt` | 03 §1 |
| 回答/文章详情 ViewModel | `shared/.../viewmodel/ArticleViewModel.kt` | 03 §1 |
| 内容详情缓存 | `shared/.../data/ContentDetailCache.kt` | 03 §1 |
| 回答切换导航器 | `shared/.../navigation/AnswerNavigator.kt` | 03 §1、03 §5 |
| 点赞支持 | `shared/.../viewmodel/VotersSupport.kt` | 04 §1 |
| 收藏 ViewModel | `...\viewmodel\CollectionsViewModel.kt` + `CollectionContentViewModel.kt` | 04 §1 |
| 评论 ViewModel | `...\viewmodel\comment\BaseCommentViewModel.kt` 等 | 04 §1 |
| 个人页 UI | `...\ui\PeopleScreen.kt` | 04 §1 |
| Rust 签名参考 | `zhihu-plus-plus/rs-zse-sign/` | 01 §4.2 |
| 知乎官方逆向 JS 参考 | `zhihu-plus-plus/misc/zse-ck-v4-*.js` | 01 §4.2 |

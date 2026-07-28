# 问题、回答与文章详情证据表

> 调研范围：`zhihu-plus-plus/` 下问题详情、回答详情、文章详情、内容渲染、回答切换相关源码及测试。所有结论以源码为据，无法确认的字段标注「待确认」。

## 1. 功能模块清单

| 模块 | Android 入口文件 | 简述 |
|---|---|---|
| 问题详情（含回答列表分页） | `shared/.../viewmodel/feed/QuestionFeedViewModel.kt` | 继承 `BaseFeedViewModel`，按 `questionId` 拉取 feeds（默认 limit=20），支持 `default`/`updated` 排序切换；支持屏蔽作者过滤；提供 `followQuestion`（POST/DELETE 签名请求）；通过 `createAnswerNavigatorFor` 从列表项构建 `QuestionAnswerNavigator` |
| 问题详情 UI | `app/src/androidTest/.../QuestionScreenInstrumentedTest.kt`（对应 `ui/QuestionScreen`） | 显示问题标题/统计/详情 markdown/可折叠预览、排序按钮、关注按钮、分享、查看日志（WebView）、评论入口 |
| 回答详情（ArticleType.Answer） | `shared/.../viewmodel/ArticleViewModel.kt`（`loadArticle` 中分支 `Answer`） | 通过 `fetchContentDetail` 取 `DataHolder.Answer`；渲染 `content` + `segmentInfos`；推入 `QuestionAnswerNavigator.answerHistory`；预取上下回答；加载赞同者分页、关系背书 |
| 文章详情（ArticleType.Article） | 同上 `ArticleViewModel.kt`（`loadArticle` 中分支 `Article`） | 通过 `fetchContentDetail` 取 `DataHolder.Article`；知乎专栏（zhuanlan）正文；不参与 `QuestionAnswerNavigator`；不加载背书 |
| 内容详情缓存 | `shared/.../data/ContentDetailCache.kt` | 单例对象，LRU 缓存（容量 100，TTL 10 分钟）按 `contentType:contentId` 缓存 `DataHolder.Content` |
| ArticleType 枚举 | `shared/.../navigation/NavDestination.kt`（第 188-197 行） | `@Serializable enum class ArticleType { Article("article"), Answer("answer") }`；**未定义 Pin**，Pin 是独立的 `NavDestination` 子类 |
| ArticleType NavType | `shared/.../navigation/ArticleTypeNavType.kt` | 自定义 `androidx.navigation.NavType<ArticleType>`；`parseValue` 默认回退到 `Article` |
| 回答切换（问题内） | `shared/.../navigation/AnswerNavigator.kt` 中的 `QuestionAnswerNavigator` | 双端队列 + 历史栈，支持上一题/下一题、预取、续链；过滤已打开回答 |
| 回答切换（收藏夹内） | 同文件 `CollectionAnswerNavigator` | 基于收藏夹 items 分页，`sourceName="「收藏夹名」"` |
| 回答切换（基于分页信息） | 同文件 `PaginationInfoNavigator` | 基于 `Answer.PaginationInfo.{prevAnswerIds,nextAnswerIds}` 续链 |
| 内容渲染（Markdown/HTML） | `shared/.../markdown/MdAst.kt` + `RenderMarkdown.kt` | 用 Ksoup 解析知乎 HTML → 自研 `com.hrm.markdown.parser.ast.Document` AST → `Markdown` Compose 渲染；不使用 ArkWeb/WebView |
| 内容渲染（HTML 解码为纯文本） | `shared/.../shared/data/HTMLDecoder.kt` | `KSerializer<String>`，用 Ksoup 解析并移除 `.invisible` 元素后取 `.text()` |
| 内容渲染（搜索高亮） | `shared/.../util/HtmlText.kt` | 自研轻量 `<em>` 解析为 `AnnotatedString`；支持数字/十六进制 HTML 实体；不支持嵌套 |
| LaTeX 公式渲染 | `shared/.../androidMain/.../latex/LatexFontDownloader.kt` | 下载 KaTeX 0.16.11 字体（npm 镜像）+ Latin Modern Math OTF（CTAN 镜像）到 `cacheDir/latex-fonts/v1`；通过 `com.hrm.latex.renderer.Latex` Composable 自研渲染（非 MathJax/KaTeX JS） |
| 文章导出（HTML/图片） | `app/src/main/assets/article_export_template.html` + `click-listener.js` + `footnotes.js` + `stylesheet.css` | WebView 离线渲染模板 |

## 2. 行为表

| 功能 | 入口 | 用户操作 | 加载态 | 成功态 | 失败态 | 返回行为 | 登录态差异 |
|---|---|---|---|---|---|---|---|
| 进入问题详情 | `QuestionScreen` | 点击问题卡 / deeplink | 显示标题"loading..." | 渲染标题/统计（N 个回答/浏览/评论/关注）/详情 markdown；可折叠预览 | 待确认 | 系统返回键退回上一页 | 未登录也可读；关注按钮需 `d_c0` cookie |
| 排序切换 | `QuestionFeedViewModel.updateSortOrder` + `refresh` | 点排序 chip | 重置列表 | 重新拉 feeds（order 变化才 refresh） | 待确认 | — | 无 |
| 关注问题 | `QuestionFeedViewModel.followQuestion` | 点关注按钮 | 按钮文本切换 | 文本变"已关注"；POST `/followers` | 文本保持"关注问题"；调 `handleFetchFailure` | — | **未登录（无 `d_c0`）静默 no-op** |
| 查看问题日志 | `QUESTION_VIEW_LOG_BUTTON_TAG` → `WebviewActivity` | 点击按钮 | — | 打开知乎网页日志页 | — | `WebviewActivity.finish()` | 无 |
| 进入问题评论 | `QUESTION_COMMENTS_BUTTON_TAG` → `CommentScreen` | 点击按钮 | wait `COMMENT_SCREEN_LIST_TAG` 显示 | 评论列表 | — | 返回问题 | 部分评论需登录 |
| 进入回答详情 | `Article`（type=Answer） NavDestination | 点击回答列表项 | title="loading..." | 渲染作者卡/正文 markdown/统计/背书/IP 属地 | `content = "<h1>你似乎来到了没有知识存在的荒原</h1>"` | 系统返回 + 水平滑动返回上一回答 | 未登录可读；投票/收藏需登录 |
| 切换上一回答 | `AnswerNavigator.goToPrevious` / `loadPrevious` | 水平滑动 / 上滑 overscroll | 预览卡显示作者名（内容为空） | 切换到 `previousAnswerContent` | 退回历史栈顶 | — | 无 |
| 切换下一回答 | `AnswerNavigator.goToNext` / `loadNext` | "下一个回答"按钮 / 下滑 overscroll | 预取中显示预览卡 | 切换到 `nextAnswerContent` | 列表耗尽返回 null | 按钮可拖回右边 | 无 |
| 点赞回答 | `ArticleViewModel.toggleVoteUp` | 点赞按钮 | — | `voteUpState`/`voteUpCount` 更新；重新拉 voters + 背书 | toast"点赞失败" | — | 需登录 |
| 进入文章详情 | `Article`（type=Article） NavDestination | 点击专栏卡片 | title="loading..." | 渲染作者/正文 markdown/IP 属地 | `content = "<h1>你似乎来到了没有知识存在的荒原</h1>"` | 系统返回 | 未登录可读 |
| 收藏 | `ArticleViewModel.toggleFavorite` | 收藏菜单 | — | toast"收藏成功"/"取消收藏成功" | toast"收藏操作失败" | — | 需登录 |
| AI 总结 | `ArticleViewModel.requestAiSummary` | "总结"按钮 | `aiSummaryLoading=true`，文本清空 | SSE 流式追加 `aiSummaryText` | `aiSummaryError` 文本提示 | — | 需登录 + xsrf |
| 导出为图片 | `ArticleViewModel.exportToImage` | 导出菜单 | WebView 渲染 15s 超时 | 保存到 MediaStore，toast"图片已保存到相册" | toast"图片导出失败" | — | 需存储权限 |
| 导出为 HTML | `ArticleViewModel.exportToHtml` | 导出菜单 | — | 保存到 Downloads/Zhihu++，toast 长消息 | toast"HTML 导出失败" | — | 需存储权限（部分版本） |
| 导出为 Markdown | `ArticleViewModel.exportToClipboard` | 导出菜单 | — | toast"文章已复制到剪贴板" | — | — | 无 |
| 标记 AIGC | `ArticleViewModel.submitAigcFlag` | AIGC 投票按钮 | `aigcVoteLoading=true` | toast"已标记疑似 AIGC" | toast"AIGC 标记失败" | — | 需投票服务配置 + voter 登录 + 积分 |

## 3. 接口表

| 功能 | URL | HTTP 方法 | 请求头 | Cookie | 请求体 | 响应字段 | 分页字段 | 错误码 | 协议类型 |
|---|---|---|---|---|---|---|---|---|---|
| 问题详情 | `https://www.zhihu.com/api/v4/questions/{questionId}` | GET | UA + include 参数 | 全量 zhihu cookie（含 `d_c0`） | 无 | `type,id,title,questionType,created,updatedTime,url,answer_count,visit_count,comment_count,follower_count,detail,excerpt,author,relationship.is_following,topics,voteup_count`（由 `zhihuContentDetailInclude` 决定） | 无 | 待确认 | JSON API |
| 问题回答列表 feeds | `https://www.zhihu.com/api/v4/questions/{questionId}/feeds?limit=20[&order={default\|updated}]` | GET | 同上 | 同上 | 无 | `data[]`（Feed 列表）+ `paging.{next,previous}` | `paging.next` URL 字符串 | 待确认 | JSON API |
| 关注问题 | `https://www.zhihu.com/api/v4/questions/{questionId}/followers` | POST / DELETE | 签名（`postSigned`/`deleteSigned`） | 需 `d_c0` | 无（POST）/ 无（DELETE） | `{}`（mock） | 无 | 待确认 | JSON API |
| 回答详情 | `https://www.zhihu.com/api/v4/answers/{answerId}` | GET | UA + include | 全量 zhihu cookie | 无 | `.settings,content,editable_content,paid_info,can_comment,excerpt,thanks_count,voteup_count,comment_count,visited_count,attachment,reaction,ip_info,pagination_info,endorsements,question.topics,question.author,reaction.relation.voting,author.badge_v2,settings.table_of_contents.enabled` | `pagination_info.{index,prev_answer_ids[],next_answer_ids[]}` | 待确认 | JSON API |
| 文章详情 | `https://www.zhihu.com/api/v4/articles/{articleId}` | GET | UA + include | 全量 zhihu cookie | 无 | `content,topics,paid_info,can_comment,excerpt,thanks_count,voteup_count,comment_count,visited_count,relationship,ip_info,relationship.vote,author.badge_v2` | 无 | 待确认 | JSON API |
| Pin 详情 | `https://www.zhihu.com/api/v4/pins/{pinId}` | GET | UA + include="topics" | 全量 zhihu cookie | 无 | 待确认（解码为 `DataHolder.Pin`） | 无 | 待确认 | JSON API |
| 回答投票 | `https://www.zhihu.com/api/v4/answers/{answerId}/voters` | POST | JSON + 签名 | 需登录 | `{"type":"UP"\|"DOWN"\|"Neutral"}` | `voteup_count` | 无 | 待确认 | JSON API |
| 文章投票 | `https://www.zhihu.com/api/v4/articles/{articleId}/voters` | POST | JSON + 签名 | 需登录 | `{"voting":1\|0}` | `voteup_count` | 无 | 待确认 | JSON API |
| 回答赞同者分页 | `https://www.zhihu.com/api/v4/answers/{answerId}/upvoters?limit=10&offset=0` | GET | UA | 全量 cookie | 无 | `data[].author`+`paging.{totals,next}` | `paging.next`、`paging.totals` | 待确认 | JSON API |
| 回答关系背书 | `https://www.zhihu.com/api/v4/answers/{answerId}/relationship?desktop=true` | GET | UA | 全量 cookie | 无 | `type,text`（`AnswerRelationshipEndorsement`） | 无 | 待确认 | JSON API |
| 收藏内容 | `https://api.zhihu.com/collections/contents/{answer\|article}/{id}` | PUT | `Content-Type: application/x-www-form-urlencoded` | 需登录 | `{add\|remove}_collections={collectionId}` | 待确认 | 无 | 待确认 | JSON API |
| 收藏列表 | `https://api.zhihu.com/collections/contents/{answer\|article}/{id}?limit=50` | GET | UA | 全量 cookie | 无 | `data[].id,is_favorited` 等 | 待确认 | 待确认 | JSON API |
| 创建收藏夹 | `https://www.zhihu.com/api/v4/collections` | POST | JSON + 签名 | 需登录 | `{"title","description","is_public"}` | 待确认 | 无 | 待确认 | JSON API |
| 收藏夹条目分页 | `https://www.zhihu.com/api/v4/collections/{collectionId}/items` | GET | UA | 全量 cookie | 无 | `data[].content`+`paging.next` | `paging.next` | 待确认 | JSON API |
| AI 总结（zhida）SSE | `https://www.zhihu.com/ai_ingress/stream/completion` | POST | `Accept: text/event-stream`+`Content-Type: application/json`+`x-xsrftoken` | 需登录 | `serializeZhidaSummaryRequest(...)`（含 `contentId,contentType,title`） | SSE 事件：`answer`(delta/全量)、`error`、`end` | 无 | HTTP 非 2xx + `error.message` | Web API（SSE） |
| 评论拉取（导出用） | `https://www.zhihu.com/api/v4/comment_v5/{answers\|articles}/{id}/root_comment?order=score&limit={N}` | GET | UA + include=`data[*].content,excerpt,headline` | 全量 cookie | 无 | `data[].content,author,created_time` | 待确认 | 待确认 | JSON API |
| LaTeX 字体下载（KaTeX） | `https://registry.npmmirror.com/katex/0.16.11/files/dist/fonts/{KaTeX_*.ttf}` | GET | 无 | 无 | 无 | 二进制 TTF | 无 | HTTP 4xx/5xx | 静态资源 |
| LaTeX 字体下载（Latin Modern Math） | `https://mirrors.ustc.edu.cn/CTAN/fonts/lm-math/opentype/latinmodern-math.otf`（fallback: `https://mirrors.tuna.tsinghua.edu.cn/...`） | GET | 无 | 无 | 无 | 二进制 OTF（验证 `OTTO` magic bytes） | 无 | HTTP 4xx/5xx | 静态资源 |
| 知乎公式图 | `https://www.zhihu.com/equation?tex={URL_ENCODED_TEX}` | GET | UA | 全量 cookie | 无 | SVG/PNG（知乎服务端渲染） | 无 | 待确认 | HTML（图片） |

## 4. ArticleType 枚举

| 值 | SerialName | 用途 | 详情 URL | include 字段差异 | 关键字段差异 |
|---|---|---|---|---|---|
| `Article` | `"article"` | 专栏文章 | `/api/v4/articles/{id}` | `content,topics,paid_info,...,relationship.vote,author.badge_v2` | `title,created,updated`；无 `question`；无 `paginationInfo`；无 `endorsements`；无 `attachment` |
| `Answer` | `"answer"` | 问题下的回答 | `/api/v4/answers/{id}` | `.settings,content,editable_content,...,attachment,reaction,ip_info,pagination_info,endorsements,question.topics,question.author,...` | `answerType,createdTime,updatedTime`；含 `question: AnswerModelQuestion`；含 `paginationInfo`；含 `endorsements`；含 `attachment` |

**关于 Pin**：`NavDestination.Pin` 是独立的 `data class Pin(val id: Long)`，**不属于 ArticleType 枚举**。详情 URL 走 `/api/v4/pins/{id}`，include 仅 `topics`，解码为 `DataHolder.Pin`。

**deeplink 解析**（`resolveContent` in `NavDestination.kt`）：
- `https://www.zhihu.com/question/{qid}/answer/{aid}` → `Article(Answer, aid)`
- `https://www.zhihu.com/answer/{aid}` → `Article(Answer, aid)`
- `https://www.zhihu.com/question/{qid}` → `Question(qid)`
- `https://www.zhihu.com/oia/articles/{aid}` → `Article(Article, aid)`
- `https://zhuanlan.zhihu.com/p/{aid}` → `Article(Article, aid)`
- `https://www.zhihu.com/appview/{pin|answer|p}/{id}` → 对应 NavDestination
- `https://www.zhihu.com/pin/{pinId}` → `Pin(pinId)`
- `zhihu://answers/{id}` / `zhihu://articles/{id}` / `zhihu://pin/{id}` / `zhihu://questions/{id}` → 对应 NavDestination

**NavType 序列化**：`ArticleTypeNavType.serializeAsValue` 输出 `name`（"Article" / "Answer"，非 SerialName）；`parseValue` 找不到时回退 `Article`。

## 5. 回答切换（AnswerNavigator）

### 5.1 抽象基类 `AnswerNavigator`（`AnswerNavigator.kt`）

- **状态字段**：
  - `answerHistory: mutableStateListOf<CachedAnswerContent>` — 已访问回答历史栈（截断前向分支）
  - `currentAnswerIndex: mutableIntStateOf` — 当前在历史中的索引（初始 -1）
  - `nextAnswerContent`/`previousAnswerContent: mutableStateOf<CachedAnswerContent?>` — 预取的相邻回答

- **导航 API**：
  - `pushAnswer(cached)` — 推入历史，若为新回答则截断 `currentAnswerIndex+1..` 的前向历史
  - `goToPrevious()` / `goToNext()` — 仅在历史栈内移动，不发起网络请求
  - `loadNext(): Article?` / `loadPrevious(): CachedAnswerContent?` — 抽象，可能触发网络
  - `prefetchNext(currentArticleId)` / `prefetchPrevious(currentArticleId)` — 抽象，后台预取

- **来源标签**：`sourceName: String`，UI 上显示"此问题"或"「收藏夹名」"

### 5.2 `QuestionAnswerNavigator`（`AnswerNavigator.kt`）

- **初始化参数**：`questionId`、`initialNextAnswers: List<Article>`（来自问题列表"往后"项）、`initialPreviousAnswers: List<Article>`（"往前"项，逆序存储）、`initialNextUrl`（feeds 续链 URL）、`order`（排序）、`getAlreadyOpenedAnswerIds`（查 `ContentOpenEventSupport` 数据库过滤已打开回答）。

- **加载策略**：
  - `ensureDestinations` 优先消费 `pendingInitialNextAnswers`；耗尽后用 `nextUrl` 请求 `/feeds?limit=6&order={order}`，若 `nextUrl` 为空则用默认 URL。
  - 用 `ContentOpenEventSupport.partitionQuestionAnswerCandidates` 把候选分到 `previousQueue` / `destinations`，去重 `enqueuedPrevIds` / `enqueuedNextIds` / `knownOpenedIds` / `historyIds`。

- **缓存策略**：所有详情经 `environment.getOrFetchContentDetail(article)` → `ContentDetailCache`（10 分钟 LRU）。

- **预取**：
  - `prefetchNext(currentArticleId)`：从 `destinations.firstOrNull()` 取下一个 Article，调 `getOrFetchContentDetail` 填充 `nextAnswerContent`。
  - `prefetchPrevious(currentArticleId)`：从 `previousQueue.firstOrNull()` 取，填充 `previousAnswerContent`。

- **续链**：`ArticleViewModel.loadArticle` 完成后调用：
  ```kotlin
  if (nav.currentAnswerIndex >= nav.answerHistory.size - 1) {
      nav.prefetchNext(article.id)  // 仅无前向历史时预取
  }
  nav.prefetchPrevious(article.id)
  ```

### 5.3 `CollectionAnswerNavigator`

- 从收藏夹 items 队列导航；`nextPageUrl` 初始为 `/api/v4/collections/{collectionId}/items`。
- `sourceName = "「$collectionTitle」"`。

### 5.4 `PaginationInfoNavigator`

- 利用 `Answer.PaginationInfo.{prevAnswerIds,nextAnswerIds}` 续链；队列为空时按 `lastKnownNextId` 拉下一个回答详情，从其 `paginationInfo` 续填双向队列。

### 5.5 转场动画 / overscroll

- `AnswerVerticalOverscroll` 组件：在回答底部继续上滑触发 `onNavigateNext`，顶部下滑触发 `onNavigatePrevious`；测试验证 700ms `swipeUp` 触发一次下一回答导航。
- `ArticleScreen` 提供"下一个回答"按钮（contentDescription="下一个回答"），可拖动到屏幕任意位置（偏好 key `buttonSkipAnswer-x`）。

## 6. 内容渲染策略

### 6.1 整体取舍

**不使用 ArkWeb/WebView 渲染正文**（仅文章导出 WebView 用模板）。Android 端通过 `ARTICLE_USE_WEBVIEW_PREFERENCE_KEY` 偏好控制是否启用 WebView（测试默认 `false`）；HarmonyOS 移植需用 Compose Multiplatform 自研 Markdown 渲染器（`com.hrm.markdown.renderer.Markdown`）或用 ArkWeb 作为首版降级方案。

### 6.2 渲染管线

1. **HTML → AST**：`htmlToMdAst(html, noNativeBlock=false)`（`MdAst.kt`）
   - 用 `Ksoup.parseBodyFragment(html)` 解析
   - 逐节点映射到 `com.hrm.markdown.parser.ast.*` 节点
   - `assignStableLineRanges` 给每个节点分配行号

2. **AST → Compose**：`RenderMarkdown(html, ...)`（`RenderMarkdown.kt`）
   - `remember(html) { htmlToMdAst(html) }` 缓存 AST
   - `document.previewImageUrls()` 收集所有图片 URL（去重、去 data: URI）用于画廊
   - 主题来自 `MarkdownTheme.material3()`，根据偏好缩放：`PREF_FONT_SIZE`（默认 100）、`PREF_LINE_HEIGHT`（默认 160）、`PREF_BLOCK_SPACING`（默认 100）
   - `deferOffscreenBlocks=true`：视口外块延迟物化（Issue #495 性能修复，首帧 5s 上限）

3. **图片**：`RenderImage` 用 `coil3.compose.AsyncImage` + `rememberMarkdownImageModel`，附加 `Cookie` + `User-Agent` 头（因为知乎图片 CDN 需要这些头）；图片宽高比由 `data-rawwidth/data-rawheight` 或 `width/height` 属性预占位；长按弹菜单：查看图片/在浏览器打开/保存/分享。

4. **链接**：`onLinkClick` → `resolveContent(url)` 转内部 NavDestination，否则 `openExternalUrl`。

5. **视频盒子**：`<a class="video-box">` 转 `NativeBlock { RenderVideoBox(videoId, thumbnailUrl) }`；`noNativeBlock=true` 时降级为普通链接。

### 6.3 Markdown 内容形态

**知乎回答/文章的 `content` 字段是 HTML 字符串**（如 `"<p data-pid='...'>...</p>"`），不是结构化 AST。`MdAst.kt` 在客户端解析为 AST。

`segmentInfos: List<SegmentInfoParagraph>` 是结构化数据，含 `pid/text/marks[].{startIndex,endIndex,segInfo}`，用于段落级划线/评论；`ArticleViewModel.loadArticle` 调用 `applySegmentInfosToHtml(content, segmentInfos, sourceUrl, contentId, contentType)` 把 segment 信息注入 HTML（在 `<span class="highlight-wrap">` 上挂 `data-highlight-*` 属性），再交给 `htmlToMdAst` 解析为 `SegmentHighlight` 节点。

### 6.4 LaTeX 公式渲染

- **不使用 KaTeX/MathJax JS**。
- 知乎 HTML 中公式以 `<img eeimg="1" src="https://www.zhihu.com/equation?tex={URL_ENCODED}" alt="{TEX}">`（行内）或 `eeimg="2"`（块级）形式存在。
- `MdAst.kt:extractEquationTex` 提取 `tex` 参数，转为 `InlineMath` 或 `MathBlock` 节点。
- `com.hrm.latex.renderer.Latex` Composable 自研渲染，依赖 `MathFont.OTF`（Latin Modern Math）+ `LatexFontFamilies`（KaTeX TTF 族）。
- 字体下载：`LatexFontDownloader.kt`，缓存到 `cacheDir/latex-fonts/v1`，写 `.done` 标记。
- `LatexEscapedCharactersInstrumentedTest` 覆盖转义字符、空格命令、无花括号上下标。

### 6.5 表格渲染

`createTableBlock` 支持 `<thead>/<tbody>/<tr>/<th>/<td>`，从 `align` 属性提取 `Table.Alignment.{LEFT,CENTER,RIGHT,NONE}`；序列化为 pipe table。

### 6.6 脚注渲染

- HTML 中 `<sup data-draft-type="reference" data-numero="N" data-text="..." data-url="...">[N]</sup>` → `FootnoteReference` + `FootnoteDefinition`。
- `footnotes.js` 在导出 WebView 中动态生成 `#zhihu-plus-footnotes` 容器，支持点击跳转和高亮。
- Compose 端：`footnoteReferenceAndBackLinkNavigateInsideOuterArticleScroll` 测试验证脚注跳转和返回。

### 6.7 HTML 解码（纯文本场景）

- `HTMLDecoder`（`HTMLDecoder.kt`）：`KSerializer<String>`，用 Ksoup 解析并移除 `.invisible` 元素后取 `.text()`；用于 `Author.headline` 等字段。
- `parseEmphasizedHtmlText`（`HtmlText.kt`）：自研解析 `<em>` 高亮，支持数字/十六进制 HTML 实体（`&#37;`/`&#x4E2D;`/`&#X1F600;`），不支持嵌套；用于搜索结果高亮等。

### 6.8 图片 CDN 域名

- `pic1.zhimg.com` / `pic2.zhimg.com` / `pic3.zhimg.com` / `pic4.zhimg.com`：标准 CDN
- `picx.zhimg.com` / `pica.zhimg.com` / `picb.zhimg.com` / `picd.zhimg.com`：动态 CDN
- 图片 URL 常带 `?source=` 参数；`extractImageUrl` 负责规范化。

## 7. 脱敏样本路径建议

建议在 `HarmonyApp/docs/evidence/samples/content-detail/` 下放置以下脱敏样本：

| 文件名 | 来源 | 用途 |
|---|---|---|
| `question_detail.json` | `GET /api/v4/questions/{id}` 响应脱敏 | 问题详情字段覆盖 |
| `question_feeds_default.json` | `GET /api/v4/questions/{id}/feeds?limit=20&order=default` 响应脱敏 | 默认排序回答列表 + `paging.next` |
| `question_feeds_updated.json` | 同上 `&order=updated` | 更新排序 |
| `question_feeds_empty.json` | 仅 `{"data":[],"paging":{"next":""}}` | 空列表边界 |
| `answer_detail.json` | `GET /api/v4/answers/{id}` 响应脱敏 | 回答详情全字段 |
| `answer_detail_with_equation.html` | 真实回答 `content` 字段脱敏 | 覆盖公式/figure/脚注/表格/视频盒子 |
| `answer_detail_long.html` | 现有 `app/src/androidTest/assets/issue-495-answer.html`（已含 148 个公式） | Issue #495 性能回归基线 |
| `answer_detail_pagination_info.json` | `pagination_info` 字段片段 | `prev_answer_ids`/`next_answer_ids` 续链验证 |
| `answer_segment_infos.json` | `segmentInfos` 字段片段 | 划线/评论段落级数据 |
| `answer_relationship.json` | `GET /api/v4/answers/{id}/relationship?desktop=true` 响应脱敏 | 背书文本 |
| `answer_upvoters_page1.json` | `GET /api/v4/answers/{id}/upvoters?limit=10&offset=0` | 赞同者分页 + `paging.totals` |
| `article_detail.json` | `GET /api/v4/articles/{id}` 响应脱敏 | 文章详情字段覆盖 |
| `article_detail_with_footnotes.html` | 专栏 `content` 脱敏 | 脚注/表格/图片组合 |
| `pin_detail.json` | `GET /api/v4/pins/{id}` 响应脱敏 | 想法详情 |
| `collection_items_page1.json` | `GET /api/v4/collections/{id}/items` 响应脱敏 | 收藏夹回答序列 |
| `ai_summary_sse_sample.txt` | `POST /ai_ingress/stream/completion` SSE 流脱敏 | `event:answer`/`event:error`/`event:end` 帧 |
| `comment_v5_root.json` | `GET /api/v4/comment_v5/answers/{id}/root_comment` 脱敏 | 评论导出 |
| `highlight_wrap_sample.html` | `<span class="highlight-wrap" data-highlight-*>` 片段 | 段落级划线属性覆盖 |
| `video_box_sample.html` | `<a class="video-box" data-lens-id>` 片段 | 视频盒子解析 |
| `latex_font_manifest.json` | KaTeX + LM Math 字体清单 + 校验和 | 字体下载完整性 |

## 8. 风险与未确认项

详见 [06-risk-register.md](./06-risk-register.md)。

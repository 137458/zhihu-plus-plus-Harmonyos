## Parent

PRD #6（第 3 批：内容详情与正文渲染）

## What to build

第 3 批基础切片：建立详情领域模型、详情接口和缓存层，为后续切片（问题/回答/文章详情页）提供数据基础。

实现内容：

- 新增 `model/QuestionDetail.ets`：问题详情模型，字段 `id/title/detail(HTML)/excerpt/answerCount/visitCount/commentCount/followerCount/voteupCount/author/topics`，提供 `fromObject(raw): QuestionDetail | null` 解析（参考 FeedCard.ets 的解析风格，逐字段 typeof 校验）
- 新增 `model/AnswerDetail.ets`：回答详情模型，字段 `id/content(HTML)/excerpt/voteupCount/commentCount/thanksCount/author/question{id,title}/ipInfo/createdTime/updatedTime`
- 新增 `model/ArticleDetail.ets`：文章详情模型，字段 `id/title/content(HTML)/excerpt/voteupCount/commentCount/author/topics/ipInfo/created/updated`
- 新增 `model/Topic.ets`：话题模型，字段 `id/name/avatarUrl?`，提供 `fromObject` 解析
- `AnswerDetail` 内嵌 `AnswerDetailQuestion`（或独立类），字段 `id/title`
- 扩展 `api/ZhihuApi.ets`：
  - `fetchQuestionDetail(questionId): Promise<QuestionDetail>`，URL `https://www.zhihu.com/api/v4/questions/{id}?include=read_count,visit_count,answer_count,voteup_count,comment_count,follower_count,detail,excerpt,author,relationship.is_following,topics`
  - `fetchAnswerDetail(answerId): Promise<AnswerDetail>`，URL `https://www.zhihu.com/api/v4/answers/{id}?include=.settings,content,editable_content,paid_info,can_comment,excerpt,thanks_count,voteup_count,comment_count,visited_count,attachment,reaction,ip_info,pagination_info,endorsements,question.topics,question.author,reaction.relation.voting,author.badge_v2,settings.table_of_contents.enabled`
  - `fetchArticleDetail(articleId): Promise<ArticleDetail>`，URL `https://www.zhihu.com/api/v4/articles/{id}?include=content,topics,paid_info,can_comment,excerpt,thanks_count,voteup_count,comment_count,visited_count,relationship,ip_info,relationship.vote,author.badge_v2`
  - 三个方法均复用 `createZse96Header` 签名、`CookieJar`，新增请求头 `User-Agent`（Web UA：`Mozilla/5.0 (X11; U; Linux x86_64; en-US) AppleWebKit/540.0 (KHTML, like Gecko) Ubuntu/10.10 Chrome/9.1.0.0 Safari/540.0`）和 `x-requested-with: fetch`
  - 风控判定复用第 2 批规则（响应非 JsonObject 或缺关键字段抛 `ApiError.riskControl`）
- 新增 `viewmodel/ContentDetailCache.ets`：详情缓存，内存 `Map<string, {data, timestamp}>`，TTL 10 分钟，`get<T>(key)`/`put<T>(key, value)`，key = `contentType + '_' + contentId`，容量超 100 时清空最早条目
- 新增设备单元测试 `ohosTest/ets/test/ContentDetail.test.ets`：覆盖 QuestionDetail/AnswerDetail/ArticleDetail/Topic 的 fromObject 解析（完整字段、缺字段、风控响应）、ZhihuApi 详情方法 URL/include 构造、ContentDetailCache TTL 过期

## Acceptance criteria

- [ ] QuestionDetail/AnswerDetail/ArticleDetail/Topic 模型使用显式 ArkTS 类型，fromObject 解析正确
- [ ] ZhihuApi.fetchQuestionDetail/fetchAnswerDetail/fetchArticleDetail 的 URL 和 include 参数与证据 03 §3 逐字一致
- [ ] 详情接口请求头包含 Web UA 和 x-requested-with: fetch
- [ ] 风控响应（非 JsonObject/缺字段）抛 ApiError.riskControl
- [ ] ContentDetailCache TTL 10 分钟过期，容量超 100 清空最早条目
- [ ] ContentDetailCache.get 未命中返回 null，命中未过期返回数据
- [ ] 设备单元测试覆盖模型解析、URL 构造、缓存 TTL，使用脱敏样本
- [ ] ArkTS 严格检查通过，hvigorw assembleHap BUILD SUCCESSFUL

## Blocked by

None - can start immediately

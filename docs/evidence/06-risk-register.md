# 风险登记表

> 本文档记录 Zhihu++ Android → HarmonyOS 移植过程中所有未确认、有争议、可能阻塞的风险。每条风险包含：编号、类别、描述、影响范围、来源/触发条件、当前状态、待确认问题或处理建议。
>
> **状态定义**：
> - **未确认**：信息不足，无法判断影响与对策
> - **已识别**：影响明确，对策已有方向但未落地
> - **已缓解**：对策已落地，风险降低但未消除
> - **已关闭**：对策已验证，风险消除
>
> **类别**：协议、签名、Cookie、安全、性能、设备适配、API 缺失、ArkWeb 限制、合规、未确认

## 1. 签名类风险

| 编号 | 风险描述 | 影响范围 | 来源 / 触发条件 | 当前状态 | 待确认问题或处理建议 |
|---|---|---|---|---|---|
| R001 | `x-zse-93` / `x-zse-96` 签名算法在 ArkTS 中能否等价复现 | 所有 Web API（首页推荐、搜索、热搜、关注、touch 上报、点赞、评论、收藏夹、个人页等 30+ 接口） | 01 §4.1：算法包含 MD5 + `ZseSigner.encryptZseV4`；02 §3 通用说明：所有 `fetchJson` / `postSigned` / `deleteSigned` 接口均签名 | 未确认 | 1. 用 01 §8 建议的 `zhihu-zse96-vector.sample.json` 已知向量回归；2. 参考 `rs-zse-sign/` Rust 实现做对照；3. MD5 在 ArkTS 端需自行实现 RFC 1329（CryptoArchitectureKit 不直接提供 MD5） |
| R002 | `ZseSigner.encryptZseV4` 的 `gTransform` 是否完全等同 SM4 线性变换 | OAuth 刷新请求体加密、`x-zse-96` 后半段加密 | 01 §4.2：`gTransform` 与 SM4 L 变换「rotateLeft 数值不同 —— 待确认是否完全等同 SM4」 | 未确认 | 1. 不假设与 SM4 等同，按 01 §4.2 原文逐字节实现；2. 用 `ZseSignerTest` 确定性测试 + 真实样本向量双重回归 |
| R003 | `ZseSigner` 测试覆盖不足，缺已知向量 | 签名算法移植后无法回归验证 | 01 §4.2：测试仅验证 `encryptZseV4("hello") == encryptZseV4("hello")` 与输入敏感，**未提供已知向量** | 已识别 | 1. 第 0 批后续补充样本采集（01 §8、02 §8 已列出样本清单）；2. 移植前必须先采集至少 5 组真实向量覆盖不同输入长度 |
| R004 | `x-zse-83` / `x-zse-84m` 加密链路是否依赖 native 库 | OAuth 刷新（`x-zse-83: 3_3.0`） | 01 §3 OAuth 刷新接口请求头使用 `x-zse-83: 3_3.0`；01 §4.2 提到 `ZseSigner.encryptZseV4` 用于 `oauth/sign_in` 请求体加密；但 01 §4.3 又说 HMAC-SHA1 在 `nativeMain` **未实现** | 未确认 | 1. 确认 `x-zse-83` 与 `x-zse-84m` 是否仅由 `ZseSigner` 一个 Kotlin 单例提供（无 native 依赖）；2. 若有 native 依赖，需评估 ArkTS 端是否能用 CryptoArchitectureKit 替代 |
| R005 | HMAC-SHA1 在 ArkTS 端可用性 | OAuth 刷新签名构造 | 01 §4.3：HMAC-SHA1 在 `jvmMain` / `androidMain` 用 `javax.crypto.Mac`；`nativeMain` **未实现** | 已识别 | 01 §4.3 已确认 HarmonyOS `@kit.CryptoArchitectureKit` 提供 HMAC-SHA1，可直接移植 |
| R006 | MD5 在 ArkTS 端可用性 | `x-zse-96` 计算（`md5Hex(signSource)`） | 01 §4.3：HarmonyOS CryptoArchitectureKit 不直接提供 MD5 | 已识别 | 1. 参考 ohpm 社区库；2. 自行实现 RFC 1329 MD5（01 §4.1 已给出 3 组测试向量）；3. 不影响安全性，仅用于签名拼接 |
| R007 | `ZseSigner` 自定义 Base64 字母表与标准 Base64 不兼容 | 签名输出、OAuth body 加密输出 | 01 §4.2：字母表 `6fpLRqJO8M/c3jnYxFkUVC4ZIG12SiH=5v0mXDazWBTsuw7QetbKdoPyAl+hN9rgE`（含 `=`），且反向遍历、与掩码异或 | 已识别 | 严格按 01 §4.2 `customEncode` 算法实现，**不可复用标准 Base64 库** |

## 2. Cookie 类风险

| 编号 | 风险描述 | 影响范围 | 来源 / 触发条件 | 当前状态 | 待确认问题或处理建议 |
|---|---|---|---|---|---|
| R008 | `d_c0` Cookie 在无 WebView 环境下如何获取 | 首次启动、匿名访问、签名 | 01 §5：`d_c0` 由知乎首次访问下发；01 §4.1：`d_c0` 为空时跳过 `x-zse-96` 签名；02 §6：`d_c0` 缺失时整体跳过 touch/read 上报 | 未确认 | 1. HarmonyOS 端用 ArkWeb 一次性访问 `https://www.zhihu.com/` 种 `d_c0`，再写入原生 CookieStore；2. 或评估能否用 HTTP 直接 GET 拿 Set-Cookie；3. 需验证 ArkWeb Cookie 与 `@kit.NetworkKit` Cookie 是否共享 |
| R009 | ArkWeb Cookie 与原生 CookieStore 是否同步 | 登录、风控、所有需要 cookie 的请求 | 01 §5 Android 端依赖 `CookieManager.getCookie` / `setCookie` 同步 WebView 与 HttpClient；HarmonyOS 端 ArkWeb 与 `@kit.NetworkKit` 是两套独立 Cookie 存储 | 未确认 | 1. 调研 ArkWeb 是否暴露 `CookieManager` 等价 API；2. 设计同步桥：登录/风控在 ArkWeb 完成后，主动把 cookie 复制到原生 CookieStore；3. 验证第三方 cookie 是否被默认屏蔽 |
| R010 | 多账号切换的存储隔离 | 多账号功能（01 §7） | 01 §7：`/account/switch` 与 `/account/sub/register` 直接签发新 token + cookie；切换后旧 token 失效；cookies 合并 `oldSession.cookies + token.cookie` | 已识别 | 1. HarmonyOS 端每个账号独立 `account.json`（或独立 preferences 命名空间）；2. 切换时整体替换 HttpClient + CookieStore；3. 验证 `q_c0` 子账号 cookie 合并语义 |
| R011 | `z_c0` 空值保护在 ArkTS 端是否复现 | 登录态稳定性 | 01 §5：`ZhihuCookieStorage.addCookie` 显式忽略 `z_c0` 为空字符串的 cookie（issue #25 修复）；防止知乎返回空值清空登录态 | 已识别 | ArkTS Cookie 写入逻辑必须保留同等的空值保护，**不可信任服务端返回的 z_c0 空值** |
| R012 | `_xsrf` cookie 与 `x-xsrftoken` 头的对应关系 | 二维码登录、AI 总结 SSE | 01 §3：QR 申请/轮询需 `x-xsrftoken`（若 `_xsrf` 存在）；03 §3：AI 总结 SSE 需 `x-xsrftoken` | 已识别 | 同步 `_xsrf` cookie 到原生 CookieStore 后，请求构造时显式读取并写入 `x-xsrftoken` 头 |
| R013 | 退出登录时 WebView/ArkWeb Cookie 是否清理 | 退出登录功能 | 01 §5：Android 端 WebView 不主动清 cookie（仅在 `configureWebLogin` 进入时调 `removeAllCookies`）；`AccountData.delete` 不清 WebView cookie | 未确认 | 1. 评估 HarmonyOS 端是否需要在退出登录时主动清 ArkWeb cookie；2. 否则可能造成账号串扰 |

## 3. ArkWeb 限制类风险

| 编号 | 风险描述 | 影响范围 | 来源 / 触发条件 | 当前状态 | 待确认问题或处理建议 |
|---|---|---|---|---|---|
| R014 | ArkWeb 加载知乎正文是否触发反爬 | 登录页、风控页、文章导出 | 01 §3 风控页面用 WebView 渲染 `https://www.zhihu.com/account/risk_control/`；03 §1 文章导出用 WebView 离线渲染模板 | 未确认 | 1. 调研 ArkWeb UA 是否可定制为 `ZHIHU_DESKTOP_USER_AGENT`；2. 实测 ArkWeb 访问知乎页面是否被反爬识别；3. 评估是否需要用原生 HTTP 抓 HTML 后注入 ArkWeb |
| R015 | ArkWeb 与原生通信桥的稳定性 | 登录、风控、文章导出、LaTeX 渲染（如采用 ArkWeb + KaTeX 方案） | 00 §6：Android `addJavascriptInterface` → ArkWeb `registerJavaScriptProxy`；03 §1 文章导出 WebView 模板用 `click-listener.js` + `footnotes.js` | 未确认 | 1. 调研 `registerJavaScriptProxy` 在 HarmonyOS 6.1.1 / API 24 的可用性与限制；2. 验证双向通信（JS → ArkTS、ArkTS → JS）；3. 评估文章导出模板是否能在 ArkWeb 等价运行 |
| R016 | ArkWeb 风控页面 cookie 注入 | 二维码登录风控分支 | 01 §3 风控页面：`cookieManager.setCookie(ZHIHU_HOME_URL, "$name=$value; Domain=.zhihu.com; Path=/")` + `flush()` | 未确认 | 1. 调研 ArkWeb 是否提供等价的 `setCookie` / `flush` API；2. 第三方 cookie 是否需要显式启用 |
| R017 | ArkWeb 加载长文章性能 | 文章导出（如使用 ArkWeb 渲染） | 03 §1：Android 端文章导出 WebView 15s 超时；Issue #495 长文章性能回归 | 已识别 | 1. 首版优先用自研 Markdown 渲染（参考 03 §6.2 管线）；2. ArkWeb 仅用于登录/风控/导出，不用于正文渲染 |

## 4. 安全类风险

| 编号 | 风险描述 | 影响范围 | 来源 / 触发条件 | 当前状态 | 待确认问题或处理建议 |
|---|---|---|---|---|---|
| R018 | 知乎 HTTPS 证书固定（certificate pinning）是否触发 | 所有 HTTPS 请求 | 01-04 文档未提及知乎服务端是否做证书固定 | 未确认 | 1. 实测 HarmonyOS 端访问知乎 API 是否被证书固定拒绝；2. 若有，评估是否需要自定义 `TLSSocket` 或绕过；3. 注意合规边界（见 R047） |
| R019 | `CLIENT_SECRET` 等公开字符串硬编码在源码 | OAuth 刷新签名 | 01 §4.3：`CLIENT_ID = "c3cef7c66a1843f8b3a9e6a1e3160e20"`、`CLIENT_SECRET = "d1b964811afb40118a12068ff74a12f4"`（公开字符串，硬编码） | 已识别 | 1. 与 Android 端保持一致，硬编码在 ArkTS；2. 不引入额外混淆；3. 不写入敏感凭据存储 |
| R020 | 账号凭据（z_c0、access_token、refresh_token）存储位置 | 多账号、会话恢复 | 01 §5 Android 端用 `account.json` 文件存储；01 §6 提到 Android 单例 `AccountData.dataState` | 已识别 | 1. HarmonyOS 端用 `@kit.AssetStoreKit`（见 R025）或加密的 preferences；2. 不可明文存储 z_c0/access_token；3. 退出登录时彻底清除 |

## 5. 协议类风险

| 编号 | 风险描述 | 影响范围 | 来源 / 触发条件 | 当前状态 | 待确认问题或处理建议 |
|---|---|---|---|---|---|
| R021 | Android UA 是否被服务端识别为非 Web | Android 首页推荐、移动身份 API | 02 §3：Android 首页用 `com.zhihu.android/Futureve/10.61.0` UA + `x-api-version=3.1.8` + `x-app-za=OS=Android&...`，**无 zse 签名**；01 §3：移动身份 API 用 `ZHIHU_ANDROID_IDENTITY_USER_AGENT` + `x-zse-93: 101_1_1.0` | 未确认 | 1. 实测 HarmonyOS 端发送同样 UA 是否被服务端识别为合法 Android 客户端；2. 若被识别为非 Android（如 HarmonyOS），评估是否需要伪装 UA；3. 注意合规边界 |
| R022 | 分页字段 `next` / `previous` 的语义 | 所有列表接口（首页、搜索、问题回答列表、赞同者、收藏夹、评论、个人页各 tab） | 03 §3：问题回答列表 feeds 响应含 `paging.{next,previous}`；02 §3：首页响应含 `paging.next`、`paging.is_end`；04 §4：`ZhihuVotersResponse.paging` 含 `previous/next/prev` 三个字段 | 未确认 | 1. 确认 `next` / `previous` / `prev` 三者的区别与使用场景；2. 是否所有接口都遵循 `paging.next` 直接复用 URL 的语义；3. 移植 `PaginationViewModel` 时统一处理 |
| R023 | 评论树结构在 04 文档未详细展开 | 评论功能（首发暂缓，第 9 批） | 04 §6：根评论响应中 `Comment.childComments` 已内嵌部分子评论；点击「查看全部回复」才拉取完整子评论；`ChildCommentViewModel` 注释「不按正常 VM 生命周期管理」 | 已识别 | 1. 第 9 批移植前补充调研评论数据结构；2. 采集 `child_comment` 响应样本；3. 评估 ArkUI 中楼中楼 UI 实现 |
| R024 | 03 §3 与 04 §3 对同一接口签名头描述不一致 | `upvoters` / `relationship` 等接口的签名判定 | 03 §3 接口表未显式列 `x-zse-93/96` 头；04 §3 明示「`x-zse-93`, `x-zse-96`, `x-requested-with: fetch`」 | 未确认 | 1. 以 04 §3 为准（更详细）；2. 实测验证；3. 统一 03 §3 与 04 §3 描述 |
| R025 | 粉丝列表走 `api.zhihu.com` 旧 API | 个人页粉丝 tab | 04 §3：`https://api.zhihu.com/people/{id}/followers` 注释「JSON API（旧 API，因签名 bug 临时回退）」 | 未确认 | 1. 实测当前是否仍走旧 API；2. 评估签名 bug 是否已修复；3. 移植时优先尝试 Web API，失败回退旧 API |
| R026 | 收藏 PUT 接口未走签名是否符合服务端预期 | 收藏/取消收藏 | 04 §3、04 §5：`PUT https://api.zhihu.com/collections/contents/{contentType}/{id}` **未走 postSigned 签名**，仅依赖 Cookie | 未确认 | 1. 实测当前服务端是否仍接受无签名 PUT；2. 若服务端升级要求签名，需切换到 postSigned |
| R027 | 评论点赞走 v4 `comments` 而非 v5 `comment_v5` | 评论点赞功能 | 04 §6：「评论点赞/取消点赞走 v4 `comments`（`/api/v4/comments/{id}/like`）—— 历史遗留，需特别注意」 | 已识别 | 严格按 04 §3 / 04 §6 实现，**不可统一到 v5** |
| R028 | 取消回答/文章点赞复用 POST 而非 DELETE | 点赞功能 | 04 §4：取消回答点赞传 `neutral`，取消文章点赞传 `0`，**不是 DELETE 方法** | 已识别 | 严格按 04 §4 实现，**不可改为 DELETE** |
| R029 | 风控判定逻辑（响应非 JSON 或缺 `$.data`） | 首页、搜索、所有 fetchJson 接口 | 02 §2：响应非 JsonObject 或缺 `$.data` 字段即抛「您可能已被风控，请重新登录」 | 已识别 | ArkTS 端复现同等判定；区分网络异常与风控 |
| R030 | 401 刷新节流（10 秒）与重放语义 | 所有登录态请求 | 01 §6：`executeZhihuAuthenticatedRequest` 收到 401 → 检查 `now - lastRefreshMillis < 10_000` → 节流直接返回 401；否则刷新 + 重放 | 已识别 | ArkTS 端复现同等节流；并发请求只允许一次刷新 |
| R031 | 主动 token 刷新间隔（≥ 1 天）触发时机 | 应用启动 | 01 §6：`MainActivity.onCreate` 后台执行；失败弹 toast 不强制重登 | 已识别 | HarmonyOS 端 `EntryAbility.onCreate` 等价实现 |

## 6. 性能类风险

| 编号 | 风险描述 | 影响范围 | 来源 / 触发条件 | 当前状态 | 待确认问题或处理建议 |
|---|---|---|---|---|---|
| R032 | 离线缓存的存储限额 | 首页启动缓存、ContentDetailCache、LaTeX 字体缓存、收藏夹导出 ZIP | 02 §5：`home_feed_startup_cache_{key}.json` 上限 10 条；03 §1：ContentDetailCache 容量 100 / TTL 10 分钟；03 §3：LaTeX 字体下载到 `cacheDir/latex-fonts/v1` | 未确认 | 1. 调研 HarmonyOS 应用沙箱存储限额（cacheDir vs filesDir）；2. 评估是否需要用 `@kit.RelationalStoreKit` 替代 JSON 文件缓存；3. 收藏夹导出 ZIP 可能较大，需评估临时文件清理 |
| R033 | 长文章渲染性能（Issue #495 回归） | 回答/文章详情 | 03 §6.2：`deferOffscreenBlocks=true` 视口外块延迟物化（首帧 5s 上限）；03 §7：`answer_detail_long.html` 含 148 个公式作为回归基线 | 已识别 | 1. 自研 Markdown 渲染器必须支持视口外块延迟物化；2. 用 `answer_detail_long.html` 等价样本做性能回归 |
| R034 | LaTeX 字体下载耗时与缓存策略 | 回答/文章中的公式渲染 | 03 §3、03 §6.4：KaTeX 0.16.11 字体（npm 镜像）+ Latin Modern Math OTF（CTAN 镜像）；缓存到 `cacheDir/latex-fonts/v1`，写 `.done` 标记 | 已识别 | 1. HarmonyOS 端首次启动后台下载；2. 验证 `OTTO` magic bytes 校验；3. 镜像源可用性（见 R048） |
| R035 | 图片 CDN 请求需带 Cookie + UA | 所有知乎图片加载 | 03 §6.2：`RenderImage` 用 `coil3.compose.AsyncImage` + `Cookie` + `User-Agent` 头（知乎图片 CDN 需要这些头） | 已识别 | HarmonyOS ArkUI Image 需自定义 ImageSource，注入 Cookie + UA 头；不可直接用 `Image(src)` |

## 7. 设备适配类风险

| 编号 | 风险描述 | 影响范围 | 来源 / 触发条件 | 当前状态 | 待确认问题或处理建议 |
|---|---|---|---|---|---|
| R036 | Asset Store Kit 在 API 24 的可用性 | 账号凭据存储 | 00 §4：技术基线 API 24 Release；01 §5、01 §6：账号凭据需安全存储 | 未确认 | 1. 调研 `@kit.AssetStoreKit` 在 API 24 的 API 完整度；2. 若不可用，回退到加密 preferences（`@kit.DataPreferencesKit` + 自实现 AES） |
| R037 | 平板双栏布局的断点策略 | tablet 设备 | 00 §3：tablet 双栏布局（master-detail），左侧导航列表 + 右侧详情，自适应断点 | 已识别 | 1. 用 ArkUI `GridRow` / `BreakpointType` 实现断点；2. 验证 phone ↔ tablet 切换（如折叠屏）；3. 回答详情的 `QuestionAnswerNavigator` 在双栏下的导航语义需重新设计 |
| R038 | phone / tablet 自适应布局验证 | 所有页面 | 00 §3：phone 单列 + 底部 TabBar + NavPathStack；tablet 双栏 | 已识别 | 1. 第 1 批移植时统一设计断点策略；2. 验证 NavPathStack 在双栏下的推入/弹出行为 |
| R039 | 2-in-1 / desktop / wearable / TV / car 不在首发范围 | 不适用 | 00 §3：2-in-1 暂缓，desktop/wearable/TV/car 不支持 | 已关闭 | 严格遵守 00 §3 范围，不投入资源 |

## 8. API 缺失类风险

| 编号 | 风险描述 | 影响范围 | 来源 / 触发条件 | 当前状态 | 待确认问题或处理建议 |
|---|---|---|---|---|---|
| R040 | `LocalRecommendationEngine` 本地推荐模型是否需要端侧推理 | 本地推荐模式（LOCAL） | 02 §1、02 §5：`LocalHomeFeedViewModel` 不走网络，依赖 `LocalRecommendationEngine`；00 §2：端侧 embedding 和推荐模型**第 10 批**，不在首发 | 已识别 | 1. 首发不支持 LOCAL 模式；2. 第 10 批移植前补充调研 `LocalRecommendationEngine` 的模型格式与推理依赖 |
| R041 | 鸿蒙缺少 KaTeX JS 库 | LaTeX 公式渲染 | 03 §6.4：Android 端**不使用 KaTeX/MathJax JS**，自研 `com.hrm.latex.renderer.Latex` Composable + Latin Modern Math OTF + KaTeX TTF 字体族 | 已识别 | 1. 优先尝试自研渲染器的 ArkUI 等价移植；2. 备选方案：ArkWeb + KaTeX JS（参考 00 §6「LaTeX 自研渲染」备注）；3. 字体下载策略见 R034 |
| R042 | 鸿蒙缺少 Coil3 图片库 | 图片加载与缓存 | 03 §6.2：`coil3.compose.AsyncImage` + `rememberMarkdownImageModel`；00 §6：Coil3 依赖 Compose，HarmonyOS 用 ArkUI Image + 自定义缓存替代 | 已识别 | 1. 自定义 ImageSource + 磁盘缓存；2. 验证知乎图片 CDN 的 Cookie + UA 注入（见 R035） |
| R043 | 鸿蒙缺少 OkHttp 拦截器链 | HTTP 客户端 | 00 §6：项目实际未使用 OkHttp，Ktor 插件机制需在 ArkTS 重实现 | 已识别 | 1. 用 `@kit.NetworkKit` 或 `@ohos/axios`；2. 自实现拦截器链：签名注入、cookie 注入、401 刷新重放、HttpCache |
| R044 | KMP 跨平台代码（commonMain）不能直接复用 | 所有 shared 模块代码 | 00 §6：Compose Multiplatform 与 ArkUI 不可互操作；Ktor 依赖 JVM；Room 是 Android 专用 | 已识别 | 1. shared/commonMain 仅作行为参考，**不直接编译**；2. ArkTS 端按 01-04 文档重写 |
| R045 | Room → relationalStore 迁移 | 本地屏蔽库、ContentOpenEventSupport | 00 §6：Android Room 数据库代码不直接复用，HarmonyOS 用 relationalStore 替代 | 已识别 | 1. 评估屏蔽列表（`blockedUserIds`）与已打开回答记录（`ContentOpenEventSupport`）的 schema；2. 用 `@kit.RelationalStoreKit` 重实现 |
| R046 | Ksoup HTML 解析兼容性 | 内容渲染、HTML 解码、搜索高亮 | 03 §1：`MdAst.kt` 用 `Ksoup.parseBodyFragment(html)`；03 §6.7：`HTMLDecoder` 用 Ksoup；00 §6：需评估 Ksoup 的 HarmonyOS 兼容性，或用 ArkWeb 解析 HTML | 未确认 | 1. 评估 Ksoup 是否有 JVM 之外的 target；2. 若不可用，用 ArkTS 端 HTML 解析库或正则；3. 备选：用 ArkWeb 离屏解析 |
| R047 | Compose Multiplatform Markdown 渲染器（`com.hrm.markdown.renderer.Markdown`）不能复用 | 内容渲染 | 03 §1、03 §6.2：自研 Compose 渲染器；00 §6：Compose 与 ArkUI 不可互操作 | 已识别 | 1. 在 ArkUI 中重写 Markdown 渲染器；2. 优先支持 paragraph/image/code/table/footnote/latex/video-box 节点；3. 性能见 R033 |
| R048 | Android zxing / JourneyApps barcode scanner 不可用 | 二维码登录扫码 | 00 §6：用 HarmonyOS `@kit.ScanKit` 替代 | 已识别 | 1. 用 `@kit.ScanKit` 实现扫码；2. 验证 `ScanKit` 在 phone / tablet 的 UX 一致性 |
| R049 | Ktor HttpClient → NetworkKit / axios 迁移 | 所有网络请求 | 00 §6：Ktor 依赖 JVM，HarmonyOS 用 `@kit.NetworkKit` 或 `@ohos/axios` 替代 | 已识别 | 1. 评估 `@kit.NetworkKit` 是否支持 multipart/form-data（touch 上报需要）、SSE（AI 总结需要）；2. 若不支持，备选 `@ohos/axios` + 自实现 SSE 解析 |

## 9. 合规类风险

| 编号 | 风险描述 | 影响范围 | 来源 / 触发条件 | 当前状态 | 待确认问题或处理建议 |
|---|---|---|---|---|---|
| R050 | 反爬绕过合规边界 | 签名、UA 伪装、cookie 同步 | R001 / R008 / R014 / R021 涉及签名复现、UA 伪装、cookie 同步等可能被视为反爬绕过的操作 | 未确认 | 1. 仅做 Android 已有行为的等价复现，**不主动绕过**知乎新增的反爬措施；2. 移植前与法务/合规团队确认边界；3. 文档化所有「未确认」项的合规风险 |
| R051 | 第三方字体下载镜像源合规 | LaTeX 字体下载 | 03 §3：`registry.npmmirror.com`（npm 镜像）、`mirrors.ustc.edu.cn` / `mirrors.tuna.tsinghua.edu.cn`（CTAN 镜像） | 已识别 | 1. 确认镜像源 ToS；2. 评估是否可换用官方源（`https://registry.npmjs.org/katex/-/katex-0.16.11.tgz`、`https://www.ctan.org/`）；3. 验证字体许可证（KaTeX MIT、Latin Modern Math OFL） |

## 10. 未确认类风险（01-04 标注的「待确认」项汇总）

> 以下风险来自 01-04 文档中显式标注「待确认」的字段。每条对应 05 §10 的同一项。

| 编号 | 风险描述 | 影响范围 | 来源 / 触发条件 | 当前状态 | 待确认问题或处理建议 |
|---|---|---|---|---|---|
| R052 | `/api/v4/me` 是否带 zse 签名头 | 会话验证 | 01 §3 接口表未显式列签名头 | 未确认 | 实测抓包确认 |
| R053 | `/udid` 响应字段与错误码 | UDID 注册 | 01 §3：响应字段「待确认」，错误用 `runCatching` 吞掉 | 未确认 | 实测抓包确认 |
| R054 | `/api/v3/oauth/captcha/v2` 响应字段 | 验证码元信息 | 01 §3：响应字段「待确认」（可能含 `show_captcha`、`captcha_url`） | 未确认 | 实测抓包确认 |
| R055 | `/api/v4/read_history/add` 响应字段与错误码 | 阅读历史加入 | 02 §3：响应字段「待确认」 | 未确认 | 实测抓包确认 |
| R056 | `/api/v4/questions/{id}` 是否带 zse 签名、错误码 | 问题详情 | 03 §3 接口表未显式列签名头 | 未确认 | 实测抓包确认；与 R024 一并处理 |
| R057 | `/api/v4/questions/{id}/feeds` 是否带 zse 签名、错误码 | 问题回答列表 | 03 §3 接口表未显式列签名头 | 未确认 | 实测抓包确认 |
| R058 | `/api/v4/answers/{id}` 是否带 zse 签名、错误码 | 回答详情 | 03 §3 接口表未显式列签名头 | 未确认 | 实测抓包确认 |
| R059 | `/api/v4/articles/{id}` 是否带 zse 签名、错误码 | 文章详情 | 03 §3 接口表未显式列签名头 | 未确认 | 实测抓包确认 |
| R060 | `/api/v4/pins/{id}` 响应字段、是否带 zse 签名、错误码 | Pin（想法）详情 | 03 §3：响应字段「待确认」（解码为 `DataHolder.Pin`） | 未确认 | 实测抓包确认；首发不含 Pin 详情页，可推迟 |
| R061 | `GET /collections/contents/{type}/{id}` 是否带 zse 签名、错误码 | 内容所在收藏夹列表 | 04 §3：签名「待确认」（走 `fetchJson` 应签名） | 未确认 | 实测抓包确认 |
| R062 | `POST /api/v4/collections` 响应字段、错误码 | 新建收藏夹 | 03 §3、04 §3：响应字段「待确认」 | 未确认 | 实测抓包确认 |
| R063 | `GET /api/v4/collections/{id}` 是否带 zse 签名、错误码 | 收藏夹详情 | 04 §3：签名未显式列出 | 未确认 | 实测抓包确认 |
| R064 | `GET /api/v4/collections/{id}/items` 是否带 zse 签名、错误码 | 收藏夹条目分页 | 03 §3、04 §3：签名未显式列出 | 未确认 | 实测抓包确认 |
| R065 | `/comment_v5/.../root_comment`（导出用）是否带 zse 签名、错误码 | 评论导出 | 03 §3：仅写「UA + include」，未显式说签名 | 未确认 | 实测抓包确认；与 04 §3 评论列表接口对齐 |
| R066 | 各个人页列表接口错误码 | 个人页各 tab | 04 §3：错误码均「待确认」 | 未确认 | 实测抓包确认 |
| R067 | `/api/v4/people/{urlToken}/favlists` 对他人访问是否受限 | 「关注订阅」tab 对他人可见性 | 04 §7：「待确认服务端是否限制」 | 未确认 | 实测抓包确认 |
| R068 | 收藏 PUT `add_collections=id1,id2` 多值支持 | 批量收藏 | 04 §5：「待确认实际服务端是否支持多值」，当前代码每次只传一个 id | 未确认 | 实测抓包确认；首发可保持单值 |
| R069 | 04 文档结构不完整 | 互动与个人页 | 04 文档在第 197 行（`urlToken` 为空时回退到 `id`）截断，未见 §8 风险与未确认项章节 | 已识别 | 1. 后续补充 04 文档；2. 已知「待确认」项已在本表 R052-R068 汇总 |

## 11. 风险统计

| 类别 | 已关闭 | 已缓解 | 已识别 | 未确认 | 合计 |
|---|---|---|---|---|---|
| 签名 | 0 | 0 | 4 | 3 | 7 |
| Cookie | 0 | 0 | 3 | 3 | 6 |
| ArkWeb 限制 | 0 | 0 | 1 | 3 | 4 |
| 安全 | 0 | 0 | 2 | 1 | 3 |
| 协议 | 0 | 0 | 7 | 4 | 11 |
| 性能 | 0 | 0 | 4 | 1 | 5 |
| 设备适配 | 1 | 0 | 3 | 1 | 5 |
| API 缺失 | 0 | 0 | 9 | 1 | 10 |
| 合规 | 0 | 0 | 1 | 1 | 2 |
| 未确认 | 0 | 0 | 1 | 17 | 18 |
| **合计** | **1** | **0** | **35** | **34** | **70** |

## 12. 进入下一批的缓解措施

按移植计划 13.2 节「进入第 1 批的条件」，本批需在进入第 1 批前推进以下缓解：

1. **签名算法基线**（R001-R007）：采集至少 5 组 `ZseSigner.encryptZseV4` 已知向量 + 5 组 `(zse93, url, dc0, body) → x-zse-96` 已知向量，作为 ArkTS 移植的回归基线。
2. **d_c0 获取方案**（R008）：在 HarmonyOS 设备上验证 ArkWeb 一次性访问 `https://www.zhihu.com/` 是否能拿到 `d_c0` cookie。
3. **ArkWeb Cookie 同步**（R009）：调研 ArkWeb `CookieManager` 等价 API，设计同步桥。
4. **详情接口签名判定**（R056-R059、R061、R063-R065）：抓包确认所有「待确认」接口的签名头。
5. **Asset Store Kit 可用性**（R036）：在 API 24 模拟器上验证 `@kit.AssetStoreKit` API 完整度。
6. **NetworkKit multipart/SSE 支持**（R049）：在 API 24 模拟器上验证 `@kit.NetworkKit` 是否支持 multipart/form-data 与 SSE。

## 13. 相关文档

- [00-scope-and-device-matrix.md](./00-scope-and-device-matrix.md) — 首发范围、设备矩阵、技术基线
- [01-auth-and-session.md](./01-auth-and-session.md) §9 — 鉴权风险初稿
- [02-home-and-search.md](./02-home-and-search.md) §9 — 首页与搜索风险初稿
- [03-content-detail.md](./03-content-detail.md) §8 — 内容详情风险初稿
- [04-interaction-and-profile.md](./04-interaction-and-profile.md) — 互动与个人页（§8 风险章节缺失，见 R069）
- [05-protocol-inventory.md](./05-protocol-inventory.md) §10 — 跨文档未确认项汇总

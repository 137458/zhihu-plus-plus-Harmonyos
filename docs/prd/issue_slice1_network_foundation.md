## Parent

第 2 批 PRD: `docs/prd/PRD_batch2_anonymous_feed_and_search.md`

## What to build

第 2 批的 prefactoring 切片：搭建网络层基础设施和领域模型，为后续所有切片提供 HTTP 客户端、zse 签名、Cookie 管理、错误处理和基础数据结构。

实现内容：

- `api/NetworkClient.ets`：基于 `@kit.NetworkKit` 的 `http` 模块封装的统一 HTTP 客户端，提供 `get(url, headers?, timeout?): Promise<HttpResponse>`，内部处理 `connectTimeout`、`readTimeout`、`HttpRequest.destroy()` 资源释放、HTTP 状态码到业务错误枚举的转换
- `api/ZseSigner.ets`：知乎 Web 签名实现，复现 `x-zse-96: 2.0_ + ZseSigner.encryptZseV4(md5Hex(zse93 + "+" + pathname + "+" + dc0 + "+" + body))` 算法（参考 01 证据 §4.2，ZB S-Box 和 ZK 轮密钥常量见证据表）
- `api/CookieJar.ets`：Cookie 管理器，只管理匿名 `d_c0`（从响应 Set-Cookie 提取，存内存），登录态 Cookie 第 4 批接入
- `model/ApiError.ets`：业务错误枚举 `enum ApiErrorCode { NETWORK_ERROR, TIMEOUT, PARSE_ERROR, RISK_CONTROL, UNAUTHORIZED, NOT_FOUND, SERVER_ERROR, UNKNOWN }` + `class ApiError { code: ApiErrorCode; message: string; cause?: Error }`
- `model/Paging.ets`：通用分页模型 `interface Paging { next: string; isEnd: boolean; previous?: string }`
- `model/Author.ets`：作者模型 `class Author { id: string; urlToken: string; name: string; avatarUrl: string; headline?: string; }`
- `model/ContentType.ets`：枚举 `enum ContentType { ANSWER, ARTICLE, QUESTION, PIN, ZVIDEO, UNKNOWN }`
- 配套本地单元测试（`entry/src/test/`）：ZseSigner 算法正确性、NetworkClient 超时和错误码映射、模型解析

## Acceptance criteria

- [ ] NetworkClient 能发起带超时的 GET 请求并在完成/异常时正确调用 `HttpRequest.destroy()` 释放资源
- [ ] NetworkClient 正确映射 HTTP 401/403/404/500/超时/网络错误到 `ApiError` 枚举
- [ ] ZseSigner 通过已知输入输出对验证（来自 01 证据 §4.2 测试向量）
- [ ] CookieJar 能从 HTTP 响应 `Set-Cookie` 头提取 `d_c0` 并在后续请求中携带
- [ ] `d_c0` 缺失时 zse 签名被跳过（与 Android 行为一致，02 §3 通用说明）
- [ ] 所有模型使用显式 ArkTS 类型，禁止 `any`/`unknown`
- [ ] 本地单元测试覆盖 ZseSigner 算法正确性和 NetworkClient 错误映射

## Blocked by

None - can start immediately

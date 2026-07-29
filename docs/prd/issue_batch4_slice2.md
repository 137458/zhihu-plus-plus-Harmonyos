## Parent

#13

## What to build

实现会话验证 API 和冷启动恢复流程（端到端：冷启动 → 从 AssetStore 加载 → 验证会话 → 恢复登录态或清除）。

### AuthApi 接口（api/AuthApi.ets）
- fetchVerifiedSession(): Promise<ZhihuSession | null>
  - GET https://www.zhihu.com/api/v4/me
  - 200 → 解析 profile，返回带 profile 的 session
  - 401/其他非 200 → 返回 null（不抛异常）
  - 使用 Web UA + 登录态 Cookie
- refreshToken(): Promise<string | null>
  - POST https://www.zhihu.com/api/account/prod/token/refresh
  - Content-Type: application/x-www-form-urlencoded
  - 依赖 cookie 中的旧 refresh_token
  - 返回新的 refresh_token
- signIn(refreshToken: string): Promise<string | null>
  - POST https://www.zhihu.com/api/v3/oauth/sign_in
  - HMAC-SHA1 签名 + ZseSigner 加密请求体
  - 字段：client_id、grant_type=refresh_token、timestamp、source=com.zhihu.web、signature、refresh_token
  - 返回 access_token

### ZseSigner 扩展
- 新增 hmacSha1Hex(key: string, message: string): string（使用 @kit.CryptoArchitectureKit）
- 新增 encryptSignInPayload(formData: string): string（复用 encryptZseV4）

### SessionViewModel（viewmodel/SessionViewModel.ets）
- @ObservedV2 单例，@Trace isLoggedIn: boolean、@Trace profile: ZhihuProfile | null
- restoreSession(): Promise<void>
  - 从 AssetStore.loadSession() 加载
  - 调用 fetchVerifiedSession() 验证
  - 200 → 恢复登录态，更新 profile，保存到 AssetStore
  - 401 → 尝试 refreshToken() + signIn() 刷新一次
  - 刷新成功 → 恢复登录态
  - 刷新失败 → 清除会话，进入未登录态
- getVerifiedProfile(): Promise<ZhihuProfile | null> —— 获取并更新 profile

### EntryAbility 冷启动恢复
- onCreate 中调用 SessionViewModel.getInstance().restoreSession()
- 恢复完成后派发事件（UI 决定是否跳转登录页）

### 单元测试
- AuthApi.test.ets：fetchVerifiedSession 解析（200/401/网络失败）；refreshToken/signIn 响应解析
- ZseSigner.test.ets 扩展：hmacSha1Hex 已知向量验证

## Acceptance criteria

- [ ] AuthApi.fetchVerifiedSession 正确解析 /api/v4/me 响应，200 返回 session，401 返回 null
- [ ] AuthApi.refreshToken 正确调用 prod/token/refresh 接口
- [ ] AuthApi.signIn 使用 HMAC-SHA1 + ZseSigner 加密请求体
- [ ] SessionViewModel.restoreSession 冷启动恢复流程正确（恢复/刷新/清除三分支）
- [ ] EntryAbility.onCreate 调用 restoreSession
- [ ] 单元测试覆盖 AuthApi 和 ZseSigner HMAC-SHA1
- [ ] hvigorw assembleHap BUILD SUCCESSFUL
- [ ] hvigorw test BUILD SUCCESSFUL

## Blocked by

- #14（Slice 1：会话模型 + AssetStore + CookieJar 扩展）

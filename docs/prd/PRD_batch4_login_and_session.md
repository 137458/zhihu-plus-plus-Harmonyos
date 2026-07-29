# PRD 第 4 批：登录与会话

## Problem Statement

作为知乎阅读用户，我希望在 HarmonyOS 应用中登录知乎账号，以便：
- 访问个人化内容（关注、收藏、历史）
- 进行授权操作（点赞、收藏、评论）
- 跨启动保持登录态，无需反复登录
- 在会话失效时被引导重新登录，而不是看到无意义的错误
- 退出登录后确保所有凭据被彻底清除，无残留授权页面

当前应用（第 1-3 批）只支持匿名阅读，无法访问授权功能。

## Solution

实现知乎 Web 端登录流程（ArkWeb 登录页 + Cookie 提取），配合会话持久化（Asset Store Kit 安全存储）、会话恢复（冷启动验证）、会话失效处理（401 自动刷新一次 + 失败引导重登）和退出登录清理。

**登录方式选择**：采用 ArkWeb 登录页（用户在 WebView 中完成知乎登录），暂不实现二维码登录（QR 登录状态机复杂，留待后续迭代）。理由：
- ArkWeb 登录是最稳妥的方案，直接复用知乎 Web 端登录页
- 避免实现复杂的 QR 状态机、风控切换、轮询逻辑
- 满足首批核心需求：登录、会话恢复、会话失效、退出

## User Stories

1. 作为未登录用户，我希望在个人页点击"登录"按钮进入登录页，以便开始登录流程
2. 作为未登录用户，我希望在登录页看到知乎登录表单（用户名/密码），以便输入凭据
3. 作为登录中用户，我希望看到加载状态，以便知道登录正在进行
4. 作为登录中用户，我希望在网络失败时看到错误提示和重试按钮，以便恢复登录
5. 作为登录中用户，我希望在用户取消登录时返回个人页，以便放弃登录
6. 作为已登录用户，我希望登录成功后自动返回个人页并看到我的头像和昵称，以便确认登录成功
7. 作为已登录用户，我希望冷启动后自动恢复登录态，以便无需每次重新登录
8. 作为已登录用户，我希望在个人页看到退出登录按钮，以便主动退出
9. 作为已登录用户，我希望点击退出登录后弹出确认对话框，以便避免误操作
10. 作为已退出用户，我希望退出后返回未登录状态（个人页显示登录提示），以便确认已退出
11. 作为已登录用户，我希望在请求返回 401 时自动刷新 token 一次，以便无感知地恢复会话
12. 作为已登录用户，我希望在 token 刷新失败时被引导重新登录，以便处理失效会话
13. 作为已登录用户，我希望在点赞/收藏等授权操作时如果未登录被引导到登录页，以便先登录再操作
14. 作为开发者，我希望 Cookie/Token 不出现在日志、源码、普通 KV 中，以便满足安全约束
15. 作为开发者，我希望会话状态在内存中跨页面同步，以便任何页面都能感知登录态变化
16. 作为开发者，我希望退出登录时清理 Web Cookie、内存会话、持久化凭据和导航栈，以便彻底清除授权状态
17. 作为已登录用户，我希望在冷启动时如果会话已过期不被进入半登录状态，以便避免看到错误数据
18. 作为已登录用户，我希望在登录成功后首页信息流使用认证态请求，以便看到个人化推荐
19. 作为已登录用户，我希望在登录页输入错误密码时看到错误提示，以便知道密码错误
20. 作为已登录用户，我希望在登录页遇到验证码/风控时 WebView 自动处理，以便完成验证流程

## Implementation Decisions

### 模块划分

**新增模块**：
- `api/AuthApi.ets`：登录相关 API（fetchVerifiedSession、refreshToken、signIn）
- `api/AssetStore.ets`：Asset Store Kit 安全存储适配层（加密存储 Cookie/Token）
- `model/ZhihuSession.ets`：会话内存模型（login/userAgent/cookies/accessToken/refreshToken/profile）
- `model/ZhihuProfile.ets`：用户资料模型（id/name/url_token/avatar_url）
- `viewmodel/SessionViewModel.ets`：全局会话状态单例（@ObservedV2 + @Trace），跨页面同步
- `viewmodel/LoginViewModel.ets`：登录页 ViewModel（管理 WebView 登录流程）
- `pages/LoginPage.ets`：重构现有占位登录页，使用 ArkWeb 加载知乎登录页

**修改模块**：
- `api/CookieJar.ets`：扩展支持 z_c0、_xsrf、q_c0 等登录 Cookie；新增持久化接口（与 AssetStore 协作）
- `api/NetworkClient.ets`：请求拦截器模式，收到 401 触发 token 刷新重试一次；登录态自动附加 Cookie/Authorization
- `api/ZhihuApi.ets`：已认证接口（fetchProfile、fetchVerifiedSession）使用登录态 Cookie/Token
- `api/ZseSigner.ets`：新增 HMAC-SHA1 签名（用于 oauth/sign_in 请求）
- `pages/ProfilePage.ets`：根据登录态切换显示（登录卡 vs 登录提示）；接入退出登录流程
- `pages/Index.ets`：路由守卫，授权页面（设置/退出）未登录时跳转登录页
- `entryability/EntryAbility.ets`：冷启动时调用 SessionViewModel.restoreSession()

### 接口契约

**AuthApi**：
- `fetchVerifiedSession(): Promise<ZhihuSession | null>` — GET /api/v4/me，200 返回会话，401 返回 null
- `refreshToken(): Promise<string | null>` — POST /api/account/prod/token/refresh，返回 refresh_token
- `signIn(refreshToken: string): Promise<string | null>` — POST /api/v3/oauth/sign_in，HMAC-SHA1 + ZseSigner 加密，返回 access_token

**AssetStore**：
- `saveSession(session: ZhihuSession): Promise<void>` — 加密存储会话到 Asset Store
- `loadSession(): Promise<ZhihuSession | null>` — 从 Asset Store 读取并解密会话
- `clearSession(): Promise<void>` — 清除存储的会话

**SessionViewModel**：
- `restoreSession(): Promise<void>` — 冷启动恢复
- `loginFromCookies(cookies: Map<string, string>): Promise<boolean>` — WebView 登录后从 Cookie 提取会话
- `refreshAndRetry(): Promise<boolean>` — 401 时刷新 token
- `logout(): Promise<void>` — 清理所有凭据
- `isLoggedIn: boolean` — 响应式登录态
- `profile: ZhihuProfile | null` — 响应式用户资料

### Cookie 管理策略

- `z_c0`：登录核心凭证，空值不写入（防覆盖）
- `d_c0`：设备标识（已有），匿名访问时获取
- `_xsrf`：CSRF token，QR 登录用（本批不用）
- 写入前校验域名 `*.zhihu.com`
- 持久化到 Asset Store Kit（加密），不进 preferences/logs

### 会话恢复流程

冷启动时：
1. 从 AssetStore 加载 ZhihuSession
2. 调用 fetchVerifiedSession() 验证（GET /api/v4/me）
3. 200 → 恢复登录态，更新 profile
4. 401 → 尝试 refreshToken() + signIn() 刷新一次
5. 刷新成功 → 恢复登录态
6. 刷新失败 → 清除会话，进入未登录态

### 会话失效处理

请求拦截器收到 401：
1. 检查节流（10 秒内已刷新过直接返回 401）
2. 调用 refreshToken() + signIn()
3. 成功 → 重放原请求
4. 失败 → 清除会话，派发未授权事件（UI 跳转登录页）

### 退出登录清理

1. 清空 CookieJar 内存
2. 清空 SessionViewModel 内存状态
3. 清空 AssetStore 持久化数据
4. 清空 Web WebView 的 Cookie（WebCookieManager）
5. 重置 NavPathStack 到首页
6. 派发退出事件（ProfilePage 切换为未登录视图）

### ArkWeb 登录页实现

- WebView 加载 `https://www.zhihu.com/signin?next=%2F`
- 桌面 UA（模拟浏览器，避免知乎返回移动端 H5）
- `onPageFinished` 时通过 `WebCookieManager.fetchCookie('https://www.zhihu.com')` 提取 cookie
- 检测到 `z_c0` 非空 → 触发 `loginFromCookies` 完成登录
- 风控/验证码由 WebView 自身处理（不拦截）
- 退出时 `WebCookieManager.clearAllCookies()` 清理

### 路由守卫

- ProfilePage 中的"设置/退出登录"入口检查登录态
- Index.ets 的 handleCardClick 对授权操作（点赞/收藏/评论）检查登录态，未登录跳转 LoginPage
- LoginPage 登录成功后 pop 回原页面或 push 到 ProfilePage

### Schema 变更

**ZhihuSession 数据模型**：
```
{
  isLoggedIn: boolean,
  userAgent: string,        // Web UA
  cookies: Map<string, string>,  // z_c0, d_c0, _xsrf, q_c0
  accessToken: string | null,
  refreshToken: string | null,
  profile: ZhihuProfile | null,
  lastRefreshMillis: number  // 节流用
}
```

**ZhihuProfile 数据模型**：
```
{
  id: string,
  name: string,
  urlToken: string,
  avatarUrl: string,
  userType: string
}
```

### 安全约束

- Cookie/Token 仅存 Asset Store Kit（加密），不进 preferences/logs
- WebView 不缓存表单数据
- 日志输出 token 时必须用 `<REDACTED>` 替换
- 网络请求日志关闭 body 打印（或脱敏）

## Testing Decisions

### 测试理念

只测试外部行为，不测试实现细节。优先测试边界层（API、存储、UI 状态切换）。

### 测试模块

**单元测试**（entry/src/ohosTest/ets/test/，需设备）：
- `SessionStore.test.ets`：AssetStore 保存/加载/清除；加密/解密正确性
- `AuthApi.test.ets`：fetchVerifiedSession 解析（200/401/网络失败）；refreshToken/signIn 响应解析
- `CookieJar.test.ets`：扩展后的 z_c0/d_c0/_xsrf 管理；空 z_c0 不写入；域名过滤
- `ZseSigner.test.ets`：已有测试扩展 HMAC-SHA1 签名验证
- `ZhihuSession.test.ets`：会话模型 fromObject/toObject

**UiTest**（Ability.test.ets 扩展）：
- `navigateToLoginFromProfile`：个人页点击登录入口 → LoginPage 可见
- `loginPageShowsWebView`：登录页 WebView 加载知乎登录页（验证 URL 或标题）
- `profileShowsUserInfoWhenLoggedIn`：登录后 ProfilePage 显示用户信息（依赖网络，失败跳过）
- `logoutClearsSession`：退出后 ProfilePage 显示未登录视图

### 已有测试先例

- `ContentDetail.test.ets`：模型 fromObject 单元测试模式
- `NetworkClient.test.ets`：设备端网络错误处理测试
- `ZseSigner.test.ets`：签名算法测试
- `Ability.test.ets`：UiTest 模式（冷启动、Tab 切换、路由跳转）

## Out of Scope

- 二维码登录（QR 状态机、风控切换、轮询逻辑）—— 留待后续迭代
- 多账号管理（账号列表、切换账号、创建子账号）—— 留待第 5 批或后续
- 移动端 API（api.zhihu.com）身份切换 —— 留待后续
- 主动 token 刷新（启动后距上次 ≥1 天后台刷新）—— 留待后续优化
- 第三方登录（微信/QQ/微博）—— 知乎 Web 端不支持，本批不实现
- 短信/邮箱验证码登录 —— 知乎 Web 端不支持，本批不实现
- 登录历史记录 —— 留待后续
- 会话过期主动检测（定时 ping /api/v4/me）—— 仅在请求返回 401 时被动处理

## Further Notes

### 风险与缓解

1. **ArkWeb Cookie 提取**：HarmonyOS Web 组件的 Cookie API（WebCookieManager）需确认可用性和异步性。缓解：先写最小可行 demo 验证 API。
2. **Asset Store Kit 可用性**：需确认设备支持。缓解：先查官方文档，若不可用回退到加密 preferences（不推荐，安全等级低）。
3. **知乎风控**：登录可能触发验证码/风控。缓解：WebView 自身处理，不拦截。
4. **Token 刷新算法**：HMAC-SHA1 + ZseSigner 加密 sign_in 请求体，需采集真实样本回归。缓解：使用 ZseSigner 已有测试模式扩展。
5. **WebView UA**：必须用桌面 UA，否则知乎返回移动端 H5 登录页。缓解：硬编码 Desktop UA。

### 依赖关系

- 本批依赖第 2-3 批的 NetworkClient、ZseSigner、CookieJar、ZhihuApi 基础
- 本批为第 5 批（核心互动）提供登录态支持
- 本批不依赖第 5-7 批的任何功能

### 验收标准（对应移植计划 13.6 节）

- ✅ 有效会话冷启动可恢复
- ✅ 过期会话不会进入半登录状态
- ✅ 登录成功后首页、详情和互动请求使用正确认证状态
- ✅ 退出后不能通过旧返回栈访问授权页面
- ✅ 日志、源码、普通 KV 和测试样本中没有敏感凭据

### Slice 划分建议

- **Slice 1**：会话模型 + AssetStore + CookieJar 扩展（ZhihuSession/ZhihuProfile 模型 + AssetStore 适配层 + CookieJar 扩展 z_c0 + 单元测试）
- **Slice 2**：AuthApi + 会话恢复（fetchVerifiedSession/refreshToken/signIn API + SessionViewModel.restoreSession + EntryAbility 冷启动恢复 + 单元测试）
- **Slice 3**：ArkWeb 登录页 + 启动登录引导（LoginPage 重构 + LoginViewModel + WebView Cookie 提取 + 登录成功跳转 + Index.ets 启动时未登录跳转 LoginPage + UiTest）
  - 用户补充：未登录时不显示匿名首页，直接跳转登录页（当前主页无登录态看不到内容）
- **Slice 4**：会话失效处理 + 退出登录（NetworkClient 401 拦截 + SessionViewModel.logout + ProfilePage 登录态切换 + 路由守卫 + UiTest）
- **Slice 5**：批次验收（端到端 UiTest + 文档同步 + 构建验证）

## Parent

#13

## What to build

实现 ArkWeb 登录页和启动登录引导（端到端：应用启动 → 未登录跳转登录页 → WebView 登录 → 提取 Cookie → 返回个人页显示用户信息）。

**用户补充需求**：未登录时不显示匿名首页，直接跳转登录页（当前主页无登录态看不到内容）。

### LoginPage 重构（pages/LoginPage.ets）
- 使用 ArkWeb Web 组件加载 https://www.zhihu.com/signin?next=%2F
- 桌面 UA（硬编码，避免移动端 H5）
- onPageFinished 回调：
  - 通过 WebCookieManager.fetchCookie('https://www.zhihu.com') 提取 cookie
  - 检测到 z_c0 非空 → 调用 SessionViewModel.loginFromCookies() 完成登录
  - 登录成功 → pop 返回上一页或 push 到 ProfilePage
- 风控/验证码由 WebView 自身处理（不拦截）
- 加载状态：Web 组件自带的 loading
- 错误状态：Web 组件 onError 显示重试按钮

### LoginViewModel（viewmodel/LoginViewModel.ets）
- 管理 WebView 登录流程状态
- loginFromCookies(cookies: Map<string, string>): Promise<boolean>
  - 提取 z_c0/d_c0/_xsrf
  - 调用 AuthApi.fetchVerifiedSession() 验证
  - 200 → 构造 ZhihuSession，调用 SessionViewModel.setSession() + AssetStore.saveSession()
  - 401 → 返回 false（登录失败）
- isLoading: boolean（@Trace）

### SessionViewModel 扩展
- setSession(session: ZhihuSession): void —— 设置会话并派发登录成功事件
- loginFromCookies(cookies: Map<string, string>): Promise<boolean> —— 委托 LoginViewModel

### Index.ets 启动登录检查
- EntryAbility 恢复会话后，SessionViewModel.isLoggedIn 为 false 时
- Index.ets 监听登录态变化，未登录则 navPathStack.pushPathByName(RouteName.LOGIN)
- 登录成功后 pop 回首页

### ProfilePage 登录态切换
- 登录态：显示用户头像、昵称、简介、功能入口列表
- 未登录态：显示登录提示卡片 + 登录按钮
- @Monitor 监听 SessionViewModel.isLoggedIn 变化

### UiTest（Ability.test.ets 扩展）
- navigateToLoginFromProfile：个人页点击登录入口 → LoginPage 可见
- loginPageShowsWebView：登录页 WebView 加载知乎登录页（验证 URL 或标题）
- profileShowsUserInfoWhenLoggedIn：登录后 ProfilePage 显示用户信息（依赖网络，失败跳过）

## Acceptance criteria

- [ ] LoginPage 使用 ArkWeb 加载知乎登录页，桌面 UA
- [ ] onPageFinished 提取 Cookie，检测 z_c0 非空触发登录完成
- [ ] LoginViewModel.loginFromCookies 正确验证会话并保存
- [ ] SessionViewModel.setSession 派发登录成功事件
- [ ] Index.ets 启动时未登录自动跳转 LoginPage
- [ ] ProfilePage 根据登录态切换显示（登录卡 vs 登录提示）
- [ ] 登录成功后返回首页/个人页显示用户信息
- [ ] UiTest 覆盖登录页可见性、登录流程
- [ ] hvigorw assembleHap BUILD SUCCESSFUL
- [ ] hvigorw test BUILD SUCCESSFUL

## Blocked by

- #14（Slice 1：会话模型 + AssetStore + CookieJar 扩展）
- #15（Slice 2：会话验证 API + 冷启动恢复）

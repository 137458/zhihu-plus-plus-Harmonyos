## Parent

#13

## What to build

实现会话失效处理、退出登录和路由守卫（端到端：401 自动刷新 / 退出登录彻底清理 / 授权页面未登录跳转登录页）。

### NetworkClient 401 拦截器
- 请求返回 401 时：
  1. 检查节流（SessionViewModel.lastRefreshMillis + 10s）
  2. 调用 AuthApi.refreshToken() + signIn() 刷新
  3. 成功 → 更新 session，重放原请求
  4. 失败 → 清除会话，派发未授权事件（ON_UNAUTHORIZED）
- 登录态自动附加 Cookie 头（从 CookieJar.buildCookieHeader()）

### SessionViewModel 扩展
- refreshAndRetry(): Promise<boolean> —— 401 时刷新 token
  - 节流检查
  - refreshToken + signIn
  - 成功 → 更新 session，保存到 AssetStore
  - 失败 → logout()，派发未授权事件
- logout(): Promise<void>
  - 清空 CookieJar 内存
  - 清空 SessionViewModel 内存状态（isLoggedIn=false, profile=null）
  - 调用 AssetStore.clearSession()
  - 调用 WebCookieManager.clearAllCookies()
  - 派发退出事件（ON_LOGOUT）
- 事件订阅：onUnauthorized / onLogout 回调列表

### ProfilePage 退出登录流程
- 登录态显示"退出登录"按钮
- 点击弹出确认对话框（AlertDialog）
- 确认后调用 SessionViewModel.logout()
- 监听 ON_LOGOUT 事件：
  - 重置 NavPathStack 到首页
  - 跳转 LoginPage

### Index.ets 路由守卫
- handleCardClick 对授权操作（点赞/收藏/评论，第 5 批实现）检查登录态
- 未登录 → pushPathByName(RouteName.LOGIN)
- 监听 ON_UNAUTHORIZED 事件 → 跳转 LoginPage
- 监听 ON_LOGOUT 事件 → 重置 NavPathStack + 跳转 LoginPage

### WebCookieManager 清理
- logout 时调用 WebCookieManager.clearAllCookies()
- 清理 WebView 缓存的登录态

### UiTest（Ability.test.ets 扩展）
- logoutClearsSession：退出后 ProfilePage 显示未登录视图
- unauthorizedRedirectsToLogin：会话失效时跳转登录页（模拟 401 较难，可跳过或用 mock）

## Acceptance criteria

- [ ] NetworkClient 401 拦截器实现，节流 10s，刷新成功重放原请求
- [ ] SessionViewModel.refreshAndRetry 正确刷新 token
- [ ] SessionViewModel.logout 清理 CookieJar/内存/AssetStore/WebCookieManager/NavPathStack
- [ ] ProfilePage 退出登录流程（按钮 + 确认对话框 + 调用 logout）
- [ ] Index.ets 路由守卫（授权操作未登录跳转登录页）
- [ ] ON_UNAUTHORIZED 事件触发跳转 LoginPage
- [ ] ON_LOGOUT 事件触发重置 NavPathStack + 跳转 LoginPage
- [ ] UiTest 覆盖退出登录流程
- [ ] hvigorw assembleHap BUILD SUCCESSFUL
- [ ] hvigorw test BUILD SUCCESSFUL
- [ ] 退出后不能通过旧返回栈访问授权页面

## Blocked by

- #14（Slice 1：会话模型 + AssetStore + CookieJar 扩展）
- #15（Slice 2：会话验证 API + 冷启动恢复）
- #16（Slice 3：ArkWeb 登录页 + 启动登录引导）

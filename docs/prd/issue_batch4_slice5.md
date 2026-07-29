## Parent

#13

## What to build

第 4 批批次验收：端到端 UiTest 验证 + 文档同步 + 构建验证。

### 端到端 UiTest（Ability.test.ets 扩展）
- coldStartRestoresSession：冷启动恢复登录态（依赖网络，失败跳过）
- loginFlowFromLoginPage：登录页完整流程（WebView 登录 → 返回个人页显示用户信息，依赖网络）
- logoutFlowClearsState：退出登录后状态清理（未登录视图 + 无法访问授权页面）
- sessionExpirationRedirects：会话失效跳转登录页（mock 或跳过）

### 文档同步
- 更新 docs/Android到HarmonyOS移植计划.md 第 13.6 节批次完成情况
- 记录 Slice 1-5 完成状态、关键文件、提交记录
- 更新 HDS 使用情况（LoginPage 是否需要 HDS）
- 更新安全约束实现情况（Asset Store Kit）

### 构建验证
- hvigorw assembleHap BUILD SUCCESSFUL
- hvigorw test BUILD SUCCESSFUL
- ArkTS 严格检查无错误
- 所有单元测试通过

### 验收标准核对（移植计划 13.6 节）
- [ ] 有效会话冷启动可恢复
- [ ] 过期会话不会进入半登录状态
- [ ] 登录成功后首页、详情和互动请求使用正确认证状态
- [ ] 退出后不能通过旧返回栈访问授权页面
- [ ] 日志、源码、普通 KV 和测试样本中没有敏感凭据

## Acceptance criteria

- [ ] 端到端 UiTest 用例编写完成（网络依赖用例失败可跳过）
- [ ] 文档同步完成（移植计划 13.6 节更新）
- [ ] hvigorw assembleHap BUILD SUCCESSFUL
- [ ] hvigorw test BUILD SUCCESSFUL
- [ ] 移植计划 13.6 节验收标准全部达成
- [ ] 所有 Slice（#14-#17）已完成并合并

## Blocked by

- #14（Slice 1：会话模型 + AssetStore + CookieJar 扩展）
- #15（Slice 2：会话验证 API + 冷启动恢复）
- #16（Slice 3：ArkWeb 登录页 + 启动登录引导）
- #17（Slice 4：Token 刷新 + 退出登录 + 路由守卫）

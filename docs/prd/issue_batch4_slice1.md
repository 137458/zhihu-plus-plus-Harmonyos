## Parent

#13

## What to build

实现会话持久化的基础层（端到端可验证：保存/加载/清除一个完整的 ZhihuSession）。

### 模型层
- ZhihuSession：会话内存模型，字段：isLoggedIn (boolean)、userAgent (string)、cookies (Map<string, string>)、accessToken (string | null)、refreshToken (string | null)、profile (ZhihuProfile | null)、lastRefreshMillis (number)
- ZhihuProfile：用户资料模型，字段：id、name、urlToken、avatarUrl、userType
- 两个模型提供 fromObject 和 toObject 方法，支持 JSON 序列化/反序列化

### 存储层
- AssetStore 适配层（api/AssetStore.ets）：封装 @kit.AssetStoreKit
  - saveSession(session: ZhihuSession): Promise<void> —— 加密存储
  - loadSession(): Promise<ZhihuSession | null> —— 读取并解密
  - clearSession(): Promise<void> —— 清除
- 存储 key 命名：zhihu_session（固定字符串）
- 加密级别：Accessibility 设备首次解锁后可用（SECURITY_LEVEL）

### CookieJar 扩展
- 现有 CookieJar 只管理 d_c0，扩展为支持 z_c0、_xsrf、q_c0
- 新增方法：
  - updateZc0(value: string): void —— 空 z_c0 不写入（防覆盖）
  - getZc0(): string | undefined
  - hasZc0(): boolean
  - updateFromSetCookieHeader 全量解析（支持多 cookie）
  - buildCookieHeader() 返回所有 cookie 拼接字符串
- 域名过滤：仅接受 *.zhihu.com 的 cookie

### 单元测试（ohosTest 设备端）
- SessionStore.test.ets：save/load/clear 循环；加密/解密正确性；空 session 处理
- CookieJar.test.ets：z_c0 空值不写入；域名过滤；buildCookieHeader 拼接正确
- ZhihuSession.test.ets：fromObject/toObject 往返；缺字段默认值；风控空对象

## Acceptance criteria

- [ ] ZhihuSession/ZhihuProfile 模型定义完成，fromObject/toObject 正确往返
- [ ] AssetStore 适配层实现完成，能保存/加载/清除 ZhihuSession
- [ ] CookieJar 扩展支持 z_c0/_xsrf/q_c0，空 z_c0 不写入，域名过滤正确
- [ ] buildCookieHeader 返回所有 cookie 正确拼接字符串
- [ ] 单元测试覆盖 SessionStore/CookieJar/模型解析
- [ ] hvigorw assembleHap BUILD SUCCESSFUL
- [ ] hvigorw test BUILD SUCCESSFUL
- [ ] Cookie/Token 不出现在日志/源码/普通 KV（用 Asset Store Kit 加密存储）

## Blocked by

None - can start immediately

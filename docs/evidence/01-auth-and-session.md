# 鉴权与会话证据表

> 本文档记录 Zhihu++ Android 工程中鉴权、签名、Cookie、登录、会话恢复、多账号管理的证据。所有结论以源码为据，无法确认的字段标注「待确认」。

## 1. 功能模块清单

| 模块 | Android 入口文件 | 简述 |
|---|---|---|
| HTTP 客户端工厂 | `shared/src/commonMain/.../shared/data/ZhihuDataTypes.kt`（`installZhihuCommonClientConfig`） | Ktor `HttpClientConfig` 扩展，统一安装 `HttpCookies`/`ContentNegotiation(json)`/`UserAgent`/可选 `HttpCache`，注入 `ZhihuCookieStorage` |
| Cookie 存储 | `shared/src/commonMain/.../shared/data/ZhihuApiClients.kt`（`ZhihuCookieStorage`） | 实现 Ktor `CookiesStorage`，过滤 `zhihu.com` 域名，丢弃空 `z_c0`，写入 `MutableMap<String,String>` |
| 已认证请求调度 | `shared/src/commonMain/.../shared/data/ZhihuApiClients.kt`（`executeZhihuAuthenticatedRequest`、`fetchZhihuAuthenticatedJson`） | 收到 401 时自动触发 `ZhihuCredentialRefresher` 刷新一次（10 秒节流），并重放原请求 |
| 会话验证 | `shared/src/commonMain/.../shared/data/ZhihuDataTypes.kt`（`fetchVerifiedZhihuAccount`、`fetchVerifiedZhihuSession`） | GET `/api/v4/me`，200 OK 才视为登录态；构造 `ZhihuAccountSession` |
| Web 签名 zse93/zse96 | `shared/src/commonMain/.../shared/util/ZhihuFetchSignature.kt` | 计算 `x-zse-93`、`x-zse-96` 头，内含纯 Kotlin MD5 实现 |
| ZSE-V4 加密 | `shared/src/commonMain/.../shared/util/ZseSigner.kt` | 自定义分组密码（SM4 变体）+ 自定义 Base64，用于 `x-zse-96` 后半段与 `sign_in` 请求体加密 |
| Token 刷新 | `shared/src/commonMain/.../util/ZhihuCredentialRefresher.kt` | 两步：先 POST `prod/token/refresh` 拿 `refresh_token`，再 HMAC-SHA1 签名后 POST `oauth/sign_in` 拿 `access_token` |
| 二维码登录 | `shared/src/commonMain/.../shared/login/QrLogin.kt` | 完整 QR 登录流程：预取 cookie → 申请二维码 → 轮询 `scan_info` → 风控处理 |
| 账号客户端 | `shared/src/commonMain/.../shared/account/ZhihuAccountClient.kt` | 会话缓存 + HttpClient 单例 + 临时 client |
| 账号仓库 | `shared/src/commonMain/.../shared/account/ZhihuAccountRepository.kt` | `ZhihuAccountSessionStore` 抽象 + JSON 序列化 |
| 移动身份切换 | `shared/src/commonMain/.../shared/account/ZhihuIdentityClient.kt` | 调 `/people/account/list`、`/account/sub/register`、`/account/switch`、`/people/self` |
| Android 实现 | `shared/src/androidMain/.../data/AccountData.kt` | 单例 `AccountData`：`ANDROID_HEADERS`、`ANDROID_USER_AGENT`、`AndroidAccountSessionStore`(File) |
| 登录页 | `app/src/main/java/.../LoginActivity.kt` | 三步声明 + 双模式（WEB/QR） |
| 错误处理 | `shared/src/commonMain/.../shared/util/ZhihuUtils.kt` | `raiseForStatus` 抛 `HttpStatusException` |

## 2. 行为表

| 功能 | 入口 | 用户操作 | 加载态 | 成功态 | 失败态 | 返回行为 | 登录态差异 |
|---|---|---|---|---|---|---|---|
| 网页登录 | `LoginActivity.configureWebLogin` | WebView 走完登录流程 | `onPageFinished` 触发 | `verifyLogin` 返回 true，弹窗"欢迎回来"，`finish()` | 弹窗"登录失败 请重试" | 通过 `CookieManager.getCookie` 读 cookie | 未登录时显示三步声明页 |
| 二维码登录 | `SharedQrLoginPane` | 扫码 → App 内确认 | 显示二维码、状态文本 | `pollQrCodeLogin` 返回 true → `finalizeLoginFromCookies` | 二维码过期；网络异常 | 状态机：扫码 → 确认 → 验证 → 成功 | 已登录用户走 `verifyAndSave` 验证 |
| 风控处理 | `pollQrCodeLogin` `onRiskControl` | 403/`code=40352`/`needLogin=true` | 切到 WebView | 用户在 WebView 完成验证 | 用户取消 → 重新生成二维码 | 切换到 `riskControlContent` | 仅 QR 模式触发 |
| Token 刷新（被动） | `executeZhihuAuthenticatedRequest` | 无用户操作 | 收到 401 → 刷新 → 重放 | 拿到新 `access_token`，原请求 200 | 抛 `IllegalArgumentException` | 10 秒节流防抖 | 未登录直接抛错 |
| Token 刷新（主动） | `MainActivity.onCreate` | 应用启动 | 距上次启动 ≥ 1 天才执行 | 日志"Zhihu token refreshed" | 弹 toast 提示重登 | 后台异步执行 | 已登录才执行 |
| 会话恢复 | `MainActivity.onCreate` → `AccountData.loadData` | 应用启动 | 同步读 `account.json` | `dataState.value` 更新 | 解析失败回退到默认空 session | 调用链：`loadData` → `accountClient.load` → `repository.load` | 未登录时返回空 session |
| 退出登录 | `AccountSettingScreen` 弹窗确认 | 点击退出 → 确认 | 删除缓存文件 → `AccountData.delete` | 关闭对话框 | 无 | `AccountData.delete` → `accountClient.clear` → 删除 `account.json` | 仅登录态可触发 |
| Profile 刷新 | `ZhihuAccountClient.refreshAndSaveProfile` | 进入账号设置页 | GET `/api/v4/me` | 保存新 session | 返回 null | 同步更新 `dataState` | 未登录返回 null |
| 多账号列表 | `ZhihuIdentityClient.listAccounts` | 进入账号管理页 | GET `/people/account/list` | 解析 `ZhihuIdentityAccount` 列表 | 抛 `ZhihuIdentityApiException` | 用 `mobileAccessToken` 作 Bearer | 必须已登录 |
| 切换账号 | `ZhihuIdentityClient.switchAccount` | 选择目标账号 | POST `/account/switch` → GET `/people/self` | 一次性保存：cookies + token + profile | 抛 `ZhihuIdentityApiException` | 必须用临时 client 验证后才保存 | 切换后旧 token 失效 |
| 创建子账号 | `ZhihuIdentityClient.createSubAccount` | 点击"创建马甲号" | POST `/account/sub/register` → GET `/people/self` | 保存新 session | 同上 | 服务器签发新 token + cookie | 主账号才可创建 |

## 3. 接口表

| 功能 | URL | HTTP 方法 | 请求头 | Cookie | 请求体 | 响应字段 | 错误码 | 协议类型 |
|---|---|---|---|---|---|---|---|---|
| 当前账号信息 | `https://www.zhihu.com/api/v4/me` | GET | `User-Agent`（来自 session） | 自动带（`z_c0`/`d_c0`/`_xsrf`） | 无 | `id`、`name`、`url_token`、`user_type`、`avatar_url` | 200=已登录；401=失效触发刷新；其他非 200 视为未登录 | Web JSON API |
| Token 中转 | `https://www.zhihu.com/api/account/prod/token/refresh` | POST | `Content-Type: application/x-www-form-urlencoded;charset=UTF-8`、`Origin`、`Referer: https://www.zhihu.com/signin`、`x-requested-with: fetch` | 自动带（含 `z_c0`） | 无（依赖 cookie 中的旧 token） | `refresh_token: String` | `raiseForStatus` 抛 ≥400；缺 `z_c0` 抛 `IllegalArgumentException` | Web JSON API |
| OAuth 刷新 | `https://www.zhihu.com/api/v3/oauth/sign_in` | POST | `Content-Type: application/x-www-form-urlencoded;charset=UTF-8`、`Origin`、`Referer`、`x-zse-83: 3_3.0`、`x-requested-with: fetch` | 自动带（必须有 `z_c0`） | `ZseSigner.encryptZseV4(formData)`（加密前字段：`client_id`、`grant_type=refresh_token`、`timestamp`、`source=com.zhihu.web`、`signature=HMAC-SHA1`、`refresh_token`） | `access_token: String` | `raiseForStatus` 抛 ≥400 | Web JSON API |
| 登录预取（HTML） | `https://www.zhihu.com/signin?next=%2F` | GET | Desktop headers（Chrome 145 UA） | 自动带 | 无 | HTML 页面（仅为种 cookie） | 待确认 | Web HTML |
| UDID 注册 | `https://www.zhihu.com/udid` | POST | Desktop headers + `Origin`、`Referer`、`x-requested-with: fetch`、`content-type: application/json;charset=UTF-8` | 自动带 | `"{}"` | 待确认（错误用 `runCatching` 吞掉） | 待确认 | Web JSON API |
| 验证码元信息 | `https://www.zhihu.com/api/v3/oauth/captcha/v2?type=captcha_sign_in` | GET | 同上 | 自动带 | 无 | 待确认（可能含 `show_captcha`、`captcha_url`） | 待确认 | Web JSON API |
| 申请二维码 | `https://www.zhihu.com/api/v3/account/api/login/qrcode` | POST | 同上 + `x-xsrftoken`（若 `_xsrf` 存在） | 自动带 | `"{}"` | `expires_at: Long?`、`link: String?`、`token: String?` / `qrcode_token: String?` | ≥400 或 token/link 为空 → 抛 `IllegalStateException` | Web JSON API |
| 二维码轮询 | `https://www.zhihu.com/api/v3/account/api/login/qrcode/{token}/scan_info` | GET | 同上 + `x-zse-93: 101_3_3.0` + `x-xsrftoken` | 自动带 | 无 | `status: Int?`、`cookie: String?`、`cookies: String?`、`z_c0: String?`、`user_id: String?`、`access_token: String?`、`success: Boolean?`、`logged_in: Boolean?`、`login_status: String?`、`error: { need_login, redirect, code, message }` | 403 + `error.code=40352` 或 `need_login=true` → 风控；网络异常 500ms 重试 | Web JSON API |
| 风控页面 | `https://www.zhihu.com/account/risk_control/` 或 `error.redirect` | GET（WebView） | `User-Agent: ZHIHU_DESKTOP_USER_AGENT`、第三方 cookie 启用 | WebView `CookieManager` 注入 | 无 | HTML | 由 WebView 处理 | Web HTML |
| 身份列表 | `https://api.zhihu.com/people/account/list` | GET | `Accept: application/json`、`User-Agent: ZHIHU_ANDROID_IDENTITY_USER_AGENT`、`x-api-version: 3.0.93`、`x-app-version: 11.2.0`、`x-app-build: release`、`x-app-bundleid: com.zhihu.android`、`x-app-flavor: zhihuwap64`、`x-app-za: OS=Android&...`、`x-network-type: WiFi`、`x-zse-93: 101_1_1.0`、`Authorization: bearer {mobileAccessToken}` | 自动带（含 `z_c0`） | 无 | `data: [{ id, url_token, name, avatar_url, is_active, can_create_sub_account, account_type, sub_account_control_status }]` | 非 200 抛 `ZhihuIdentityApiException` | 移动 JSON API |
| 创建子账号 | `https://api.zhihu.com/account/sub/register` | POST | 同身份列表头（无 `Content-Type`） | 自动带 | 无（不发送 body） | `uid`、`user_id`、`token_type: "bearer"`、`access_token`、`refresh_token`、`expires_in`、`cookie: { z_c0, q_c0, ... }`、`expires_at` | 同上 | 移动 JSON API |
| 切换账号 | `https://api.zhihu.com/account/switch` | POST | 同身份列表头 + `Content-Type: application/json` | 自动带 | `{"target_user_id": "{userId}"}` | 同上 | 同上；profile.id 必须等于 target_user_id | 移动 JSON API |
| 新身份验证 | `https://api.zhihu.com/people/self` | GET | 同身份列表头，`Authorization` 用新签发的 token | 用新 cookies 创建临时 client | 无 | `id`、`url_token`、`name`、`user_type`、`avatar_url`、`can_create_sub_account`、`account_type` | 非 200 抛异常 | 移动 JSON API |

## 4. 签名与加密算法

### 4.1 zse93 / zse96（Web 签名，`ZhihuFetchSignature`）

**位置**：`shared/src/commonMain/.../shared/util/ZhihuFetchSignature.kt` + 扩展函数 `signZhihuFetchRequest`

**触发场景**：所有 Web API 请求（`x-zse-93: 101_3_3.0`）；QR 轮询时显式设置；不依赖登录态。

**计算流程**：

1. 从 cookie 取 `d_c0`（若为空则跳过签名，仅设 `x-zse-93`、`x-zse-96` 不写入）。
2. 提取 URL pathname：`"/" + url.substringAfter("//").substringAfter('/')`（去掉 scheme 与 host，保留 path+query）。
3. 拼接 `signSource`：
   ```
   signSource = zse93 + "+" + pathname + "+" + dc0 + "+" + body
   ```
   `body` 仅当 `Content-Type: application/json` 且 body 为 `String` 或可序列化对象时才加入。
4. 计算 `md5Hex(signSource)` —— 纯 Kotlin 实现，标准 RFC 1329 MD5（32 字符小写 hex）。
   - 测试向量：`md5("")=d41d8cd98f00b204e9800998ecf8427e`、`md5("abc")=900150983cd24fb0d6963f7d28e17f72`、`md5("hello")=5d41402abc4b2a76b9719d911017c592`
5. 最终 `x-zse-96 = "2.0_" + ZseSigner.encryptZseV4(md5Hex(signSource))`。
6. 同时设置 `x-requested-with: fetch`。

### 4.2 ZseSigner.encryptZseV4（`ZseSigner` 单例）

**位置**：`shared/src/commonMain/.../shared/util/ZseSigner.kt`

**用途**：
- `x-zse-96` 后半段（输入是 MD5 hex 字符串）
- `oauth/sign_in` 请求体加密（输入是 form-urlencoded 字符串）

**算法概要**：

1. **头部填充**：明文前加两字节 `0xD2, 0x00`，再拼接输入 UTF-8 字节。
2. **PKCS7 填充**：补齐到 16 字节倍数（pad = 16 - size % 16）。
3. **首块预处理**：明文前 16 字节与 `KEY16 = "059053f7d15e01d7".encodeToByteArray()` 逐字节异或，再异或 `0x2A`。
4. **rBlock（核心分组加密，SM4 变体）**：
   - 输入 16 字节，按 BE 读 4 个 u32。
   - 32 轮迭代：`tr[i+4] = tr[i] XOR gTransform(tr[i+1] XOR tr[i+2] XOR tr[i+3] XOR ZK[i])`。
   - `ZK`：32 个 u32 常量（在源码中硬编码，例如 `1170614578u, 1024848638u, ...`）。
   - `gTransform`：将 u32 拆为 4 字节 → 查 `ZB`（256 字节 S-Box）→ 重组 u32 → 与自身的 `rotateLeft(2/10/18/24)` 异或（线性变换，与 SM4 L 变换一致但 rotateLeft 数值不同 —— 待确认是否完全等同 SM4）。
   - 输出 16 字节，顺序反转（`tr[35]→out[0]`，`tr[32]→out[12]`）。
5. **xBlocks（CBC 模式）**：从第 17 字节起，每 16 字节与上一块密文异或后用 rBlock 加密。首块密文即 rBlock(first)。
6. **customEncode（自定义 Base64 变体）**：
   - 反向遍历字节（从 `p = size - 1` 到 0，步长 3）。
   - 每个字节与掩码异或：`m = 0x3A >>> (8 * (i % 4)) & 0xFF`，其中 `i` 是单调递增计数器。
   - 每 3 字节编为 4 字符（24 位 → 4 个 6 位）。
   - 字母表：`"6fpLRqJO8M/c3jnYxFkUVC4ZIG12SiH=5v0mXDazWBTsuw7QetbKdoPyAl+hN9rgE"`（含 `=`，与标准 Base64 不同）。
   - 末尾不足 3 字节补零。

**测试覆盖**（`ZseSignerTest.kt`）：
- 仅验证 `encryptZseV4("hello") == encryptZseV4("hello")`（确定性）
- `encryptZseV4("hello") != encryptZseV4("world")`（输入敏感）
- **未提供已知向量**，移植后必须采集真实样本作回归基线。

**辅助资源**：
- `zhihu-plus-plus/rs-zse-sign/` — Rust 实现，可作为算法参考
- `zhihu-plus-plus/misc/zse-ck-v4-*.js` — 知乎官方逆向 JS 参考

### 4.3 HMAC-SHA1（`ZhihuCredentialRefresher.hmacSha1Hex`）

**位置**：`expect fun`，平台实现：
- `shared/src/jvmMain/.../ZhihuCredentialRefresherPlatform.jvm.kt`：`javax.crypto.Mac` + `SecretKeySpec("HmacSHA1")`
- `shared/src/androidMain/.../ZhihuCredentialRefresherPlatform.android.kt`：同上
- `shared/src/nativeMain/.../ZhihuCredentialRefresherPlatform.native.kt`：**未实现**

**签名构造**（`generateRefreshPayload`）：
```
message = grantType + clientId + source + timestamp
signature = hmacSha1Hex(clientSecret, message)  // 小写 hex
```
- `CLIENT_ID = "c3cef7c66a1843f8b3a9e6a1e3160e20"`（公开字符串，硬编码）
- `CLIENT_SECRET = "d1b964811afb40118a12068ff74a12f4"`（公开字符串，硬编码）
- `GRANT_TYPE = "refresh_token"`
- `SOURCE = "com.zhihu.web"`
- `timestamp = Clock.SYSTEM.now().toEpochMilliseconds()`（毫秒）

**ArkTS 可复现性**：HarmonyOS `@kit.CryptoArchitectureKit` 提供 HMAC-SHA1，可直接移植；MD5 需要纯 TS 实现（HarmonyOS Crypto Architecture Kit 不直接提供 MD5，因其已不推荐用于安全用途，但用于签名仍可用，可参考 ohpm 社区库或自行实现 RFC 1329）。

## 5. Cookie 管理策略

**存储位置**：`ZhihuCookieStorage` 持有 `MutableMap<String, String>`，由调用方传入（Android 端来自 `AccountData.data.cookies` / `ZhihuAccountSession.cookies`）。

**写入规则**（`addCookie`）：
1. `cookie.name == "z_c0" && cookie.value.isBlank()` → **直接丢弃**（不覆盖已有 z_c0，防止知乎返回空值清空登录态；issue #25 注释）。
2. `cookie.domain?.endsWith("zhihu.com") != false` → 写入 map；其他域名丢弃。
3. 写入后触发 `onCookieChanged` 回调（Android 端会持久化到 `account.json`）。

**读取规则**（`get`）：
- 返回所有 cookies，统一设置 `domain = "www.zhihu.com"`、`CookieEncoding.RAW`。
- Ktor 会自动把它们附加到请求头作为 `Cookie:` 字段。

**关键 cookie 字段**：

| Cookie 名 | 用途 | 来源 | 过期处理 |
|---|---|---|---|
| `z_c0` | 登录凭证（核心） | 知乎登录后下发；QR 登录从 `scan_info.z_c0` 或 Set-Cookie 提取 | 空 z_c0 不写入；失效后 401 触发刷新 |
| `d_c0` | 设备标识（签名密钥） | 知乎首次访问下发 | 无显式过期；为空时跳过 zse-96 签名 |
| `_xsrf` | CSRF token | 知乎 Set-Cookie | 用于 `x-xsrftoken` 头（QR 登录时） |
| `q_c0` | 子账号 cookie | `/account/switch` 或 `/account/sub/register` 响应中 `cookie` 字段 | 切换账号时合并到 session |

**WebView 中的 cookie 同步**（Android）：
- 登录成功后 `CookieManager.getInstance().getCookie(ZHIHU_HOME_URL)` → `parseCookieAssignments` → `AccountData.verifyLogin`。
- 风控 WebView 注入 cookie：`cookieManager.setCookie(ZHIHU_HOME_URL, "$name=$value; Domain=.zhihu.com; Path=/")` + `flush()`。
- `parseCookieAssignments` 跳过 `Domain`/`Path`/`Expires`/`Max-Age`/`HttpOnly`/`Secure`/`SameSite` 等 cookie 属性。

**清除规则**：
- `ZhihuAccountClient.clear()` → `invalidateHttpClient` + `repository.clear()`（删除 `account.json`）。
- `AccountData.delete(context)` 调用上述 + 删除 `homeFeedStartupCacheFileNames()` 列出的缓存文件。
- WebView 不主动清 cookie（仅在 `configureWebLogin` 进入时调 `removeAllCookies`）。

## 6. 会话恢复与失效

**应用启动会话恢复**（`MainActivity.onCreate`）：
1. `AccountData.loadData(this)` → `accountClient(context).load()`。
2. `ZhihuAccountClient.load`：
   - 优先返回内存缓存 `session`；
   - 否则 `repository.load()` → `store.readText()` → JSON 解析为 `ZhihuAccountSession`；
   - 解析失败/空文件 → 返回默认 `ZhihuAccountSession()`（`login=false`、`userAgent=DEFAULT_ZHIHU_USER_AGENT`、空 cookies）。
3. Android 单例存到 `AccountData.dataState: MutableStateFlow<Data>`，UI 通过 `collectAsState` 响应。
4. **主动刷新**：若 `now - lastLaunchTimestamp >= 1 天`，后台执行 `fetchRefreshToken` + `refreshZhihuToken`；失败弹 toast 不强制重登。

**会话失效处理**（请求级）：
- `executeZhihuAuthenticatedRequest` 收到 401：
  1. 检查 `Clock.SYSTEM.now() - lastRefreshMillis < 10_000` → 节流，直接返回 401。
  2. 否则调 `fetchRefreshToken`（POST `prod/token/refresh`，依赖 cookie 中的旧 refresh_token）。
  3. 再调 `refreshZhihuToken`（HMAC-SHA1 签名 + ZseSigner 加密 → POST `oauth/sign_in`）。
  4. 更新 `lastRefreshMillis`。
  5. 重放原请求 → `raiseForStatus`。
- `refreshZhihuToken` 前置校验：cookie 中必须有 `z_c0`，否则抛 `IllegalArgumentException("刷新失败：缺失关键 cookie z_c0，请重新登录")`。
- `fetchVerifiedZhihuSession` 中 HTTP 非 200 → 返回 null（不抛异常）。

**退出登录清理**（`AccountData.delete` → `ZhihuAccountClient.clear`）：
1. `homeFeedStartupCacheFileNames().forEach { File(context.filesDir, it).delete() }`（Android 端）。
2. `AccountData.delete(context)` → `accountClient.clear()`。
3. `ZhihuAccountClient.clear`：
   - `session = ZhihuAccountSession()`（空）；
   - `onSessionChanged(emptySession)` 通知 UI；
   - `invalidateHttpClient()`：`httpClient?.close()` + 清空缓存字段；
   - `repository.clear()` → `store.delete()` → 删除 `account.json`。

**HttpClient 失效场景**（`ZhihuAccountClient`）：
- `save(session)` 时若 `httpClientCookies != session.cookies || httpClientUserAgent != session.userAgent` → invalidate。
- `cookieChange` 回调（HTTP 响应更新 cookie）→ 同步保存到 repository，但 **不** invalidate。
- Android 端：`httpClient(context)` 绑定 `LifecycleOwner.onDestroy` → 自动 invalidate。

## 7. 多账号管理

**数据模型**（`ZhihuIdentityAccount`）：
- `id: String`（账号 ID）
- `urlToken: String?`（账号 URL 标识）
- `name: String`（昵称）
- `avatarUrl: String?`
- `isActive: Boolean`（当前是否激活）
- `canCreateSubAccount: Boolean`（是否可创建子账号）
- `accountType: Int`（1=主账号，2=子账号/马甲号）
- `subAccountControlStatus: Int`

**接口流程**：
1. **列出身份**：`GET /people/account/list` → 返回 `data: ZhihuIdentityAccount[]`。
2. **创建子账号**：`POST /account/sub/register`（无 body）→ 服务器返回新 token + cookie。
3. **切换账号**：`POST /account/switch`，body `{"target_user_id": "{userId}"}` → 同上。
4. **验证并保存**（`applyIssuedToken`）：
   - 检查 `token.accessToken` 非空、`token.cookie["z_c0"]` 非空。
   - 合并 cookies：`oldSession.cookies + token.cookie`。
   - 创建临时 client（用新 cookies）→ `GET /people/self` → 解析 profile。
   - 检查 `profile.id` 非空 + 与 `expectedAccountId` 一致。
   - 一次性构造新 `ZhihuAccountSession` 并 `saveSession`。
5. **失败处理**：HTTP 非 200 抛 `ZhihuIdentityApiException(message, statusCode)`。

**关键约束**（来自源码注释）：
> `/account/sub/register` 与 `/account/switch` 都会直接签发目标身份的新 token 和 cookie。收到响应后必须先用新凭证请求 `/people/self`，再一次性保存完整会话；仅替换用户 ID 会让后续推荐和互动请求继续落在旧身份。

## 8. 脱敏样本路径建议

建议在 `HarmonyApp/docs/evidence/samples/auth/` 下放置以下样本（所有真实值用 `<placeholder>` 占位）：

| 文件名 | 内容 | 用途 |
|---|---|---|
| `zhihu-me-response.sample.json` | `/api/v4/me` 200 响应（脱敏 id/name/url_token/avatar_url） | 验证会话解析 |
| `zhihu-me-unauthorized.sample.json` | 401 响应（`{"error":"unauthorized"}`） | 验证失效检测 |
| `zhihu-token-refresh-response.sample.json` | `prod/token/refresh` 响应（`refresh_token` 占位） | 验证 token 中转 |
| `zhihu-sign-in-response.sample.json` | `oauth/sign_in` 响应（`access_token` 占位） | 验证 OAuth 刷新 |
| `zhihu-sign-in-request-form.sample.txt` | `sign_in` 加密前的 form 字段（全脱敏） | 用于复算 ZseSigner 输入 |
| `zhihu-zse96-vector.sample.json` | 一组 `(zse93, url, dc0, body) → x-zse-96` 已知向量（dc0 脱敏） | 移植后算法回归 |
| `zhihu-zse-signer-vector.sample.json` | `ZseSigner.encryptZseV4("hello")` 等多组输入 → 输出（无敏感数据） | 自定义 Base64 + SM4 变体回归 |
| `zhihu-qr-code-response.sample.json` | `qrcode` 响应（`token`/`link`/`expires_at` 脱敏） | 二维码申请解析 |
| `zhihu-qr-scan-info-waiting.sample.json` | `scan_info` 等待扫码响应 | 状态机解析 |
| `zhihu-qr-scan-info-scanned.sample.json` | `scan_info` 已扫码响应 | 触发 `onScanned` |
| `zhihu-qr-scan-info-success.sample.json` | `scan_info` 登录成功响应（全脱敏） | 成功判定 |
| `zhihu-qr-scan-info-expired.sample.json` | `scan_info` 过期响应 | 过期判定 |
| `zhihu-qr-scan-info-risk-control.sample.json` | 403 风控响应（`error.code=40352`、`error.redirect` 脱敏） | 风控分支 |
| `zhihu-identity-list-response.sample.json` | `/people/account/list` 响应（主账号 + 子账号，全脱敏） | 多账号列表解析 |
| `zhihu-identity-switch-response.sample.json` | `/account/switch` 响应（`access_token`/`refresh_token`/`cookie`/`expires_at` 脱敏） | 切换账号解析 |
| `zhihu-identity-self-response.sample.json` | `/people/self` 响应（脱敏） | 新身份验证 |
| `zhihu-captcha-v2-response.sample.json` | `captcha/v2` 响应 | 验证码字段待确认 |
| `zhihu-account-session-stored.sample.json` | 序列化后的 `account.json`（所有 cookie/token 占位） | 验证持久化格式 |

**命名规则**：`{接口名简称}-{场景}.sample.{ext}`，全小写连字符；所有敏感字段用 `<REDACTED:字段名>` 替换；时间戳用 `1700000000` 这种固定占位。

## 9. 风险与未确认项

详见 [06-risk-register.md](./06-risk-register.md)。

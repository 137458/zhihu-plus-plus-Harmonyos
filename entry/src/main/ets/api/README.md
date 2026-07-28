# api/

HTTP 客户端、协议适配和鉴权适配目录。

## 职责

- 请求构造、响应解析、超时、错误转换和协议兼容
- 每次请求明确超时时间和资源释放（`http.HttpRequest.destroy()`）
- 鉴权头注入、Cookie 管理、会话过期处理
- 接口解析失败、字段缺失和错误码转换

## 设计约束

- 使用 `@kit.NetworkKit` 的 `http` 模块，不引入第三方 HTTP 库
- 所有请求必须设置 `connectTimeout` 和 `readTimeout`
- 响应解析必须显式校验字段类型，禁止 `as` 强转绕过检查
- 敏感信息（Token / Cookie）不进入日志
- 错误码统一映射为业务错误枚举，避免在 ViewModel 中处理 HTTP 细节

## 后续批次规划

| 批次 | 内容 |
|---|---|
| 第 2 批 | NetworkClient、首页推荐接口、搜索接口、分页协议 |
| 第 3 批 | 问题详情、回答详情、文章详情接口 |
| 第 4 批 | 登录接口、会话恢复、Token 刷新 |
| 第 5 批 | 点赞、收藏、评论、个人页接口 |

## 引用

- 移植计划：`docs/Android到HarmonyOS移植计划.md` 第 5.1 节分层规则
- 证据库：`docs/evidence/05-protocol-inventory.md` 协议清单
- AGENTS.md：网络层安全约束

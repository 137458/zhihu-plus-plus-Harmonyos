# 证据与范围冻结（第 0 批交付物）

本目录是 Zhihu++ Android 到 HarmonyOS 移植第 0 批「证据与范围冻结」的输出物，记录从 Android 参考工程中提取的行为、接口、协议与风险证据。所有内容仅供 HarmonyOS 移植参考，不作为运行时依赖。

## 文档索引

| 文件 | 内容 |
|---|---|
| [00-scope-and-device-matrix.md](./00-scope-and-device-matrix.md) | 首发范围清单、暂缓清单、设备矩阵、技术基线 |
| [01-auth-and-session.md](./01-auth-and-session.md) | 鉴权、签名、Cookie、登录、会话恢复、多账号 |
| [02-home-and-search.md](./02-home-and-search.md) | 首页推荐（Web/Android/混合/本地）、搜索、热搜、阅读上报 |
| [03-content-detail.md](./03-content-detail.md) | 问题详情、回答详情、文章详情、内容渲染、回答切换 |
| [04-interaction-and-profile.md](./04-interaction-and-profile.md) | 点赞、收藏、评论、个人页、关注、基础设置 |
| [05-protocol-inventory.md](./05-protocol-inventory.md) | 接口汇总清单（按功能域分类，含签名/Cookie/请求体/响应字段/未确认项/协议常量） |
| [06-risk-register.md](./06-risk-register.md) | 风险清单（70 条，按 10 个类别分组，含状态与处理建议） |

## 证据采集原则

1. **以源码为据**：所有结论必须有 Android 工程源码或测试代码支撑，无法确认的字段标注「待确认」。
2. **脱敏优先**：所有样本严禁包含真实 Cookie、Token、账号、手机号、私有地址。
3. **协议分类**：明确区分 Web API（带 zse 签名）、JSON API（api.zhihu.com）、HTML、静态资源。
4. **登录态差异**：每个接口必须说明匿名访问与登录访问的差异。
5. **边界严守**：本目录文件不引用 Android 工程源码作为运行时依赖，只作为行为和协议参考。

## Android 参考工程位置

`HarmonyApp/zhihu-plus-plus/`（独立 git 仓库，已被 `.gitignore` 忽略，不纳入 HarmonyOS 仓库提交）

主要参考源：
- `zhihu-plus-plus/shared/src/commonMain/kotlin/com/github/zly2006/zhihu/` — KMP 跨平台代码
- `zhihu-plus-plus/shared/src/androidMain/` — Android 平台实现
- `zhihu-plus-plus/app/src/main/` — Android 应用入口
- `zhihu-plus-plus/app/src/androidTest/` — 仪器测试（行为证据）
- `zhihu-plus-plus/shared/src/commonTest/` 与 `shared/src/jvmTest/` — 单元测试
- `zhihu-plus-plus/third_party/markdown/` — Markdown 处理子工程
- `zhihu-plus-plus/rs-zse-sign/` — ZSE 签名 Rust 实现（算法参考）

## 进入下一批（第 1 批）的条件

按移植计划 13.2 节：

- [x] 首发功能都有行为证据（覆盖 01-04 四个领域）
- [ ] 首页、搜索、问题详情、回答详情和登录接口都有可重放样本，或明确列出待确认项
- [x] 已确认匿名请求与登录请求的差异（见各文档「登录态差异」段）
- [x] 已确认账号凭据的存储和清除策略（见 01-auth-and-session.md §5、§6）

脱敏样本的实际采集需要 Android 设备运行参考工程并抓包，不在本批代码调研范围内。样本清单与命名规则已列在 [07-sample-inventory.md](./07-sample-inventory.md)（如创建），实际样本采集作为第 0 批后续补充工作。

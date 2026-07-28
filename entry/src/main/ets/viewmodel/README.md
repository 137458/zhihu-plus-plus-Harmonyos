# viewmodel/

页面状态和业务操作目录。

## 职责

- 加载、分页、错误、空态、重复操作和失败回滚的统一管理
- 使用 `@ObservedV2` + `@Trace` 暴露状态给 ArkUI 页面
- 调用 `api/` 层发起请求，将响应转换为 `model/` 实例
- 处理页面生命周期内的状态机转换（加载中 / 成功 / 失败 / 空数据）

## 设计约束

- ViewModel 类使用 `@ObservedV2`，需观察的属性用 `@Trace` 装饰
- 不直接持有 ArkUI 组件引用，避免内存泄漏
- 异步操作必须可取消（页面销毁时通过 `aboutToDisappear` 取消）
- 错误状态必须包含错误码、用户可读消息、是否可重试三个字段

## 后续批次规划

| 批次 | 内容 |
|---|---|
| 第 2 批 | 首页推荐流 ViewModel、搜索 ViewModel |
| 第 3 批 | 问题详情、回答详情、文章详情 ViewModel |
| 第 4 批 | 登录、会话恢复 ViewModel |
| 第 5 批 | 点赞、收藏、评论、个人页 ViewModel |

## 引用

- 移植计划：`docs/Android到HarmonyOS移植计划.md` 第 5.1 节分层规则
- AGENTS.md：状态管理 V2 装饰器使用约束

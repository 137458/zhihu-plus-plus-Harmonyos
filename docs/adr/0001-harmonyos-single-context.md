# ADR-0001：采用单上下文 HarmonyOS 工程

## 状态

已接受

## 决策

HarmonyApp 使用根目录 `CONTEXT.md` 和 `docs/adr/` 的 single-context 领域文档布局。嵌套 Android 工程保持为参考边界，不建立第二套 Agent 技能上下文。

## 原因

当前 HarmonyOS 工程只有一个 `entry` 主模块，Android 工程不参与 HarmonyOS 构建。拆分上下文会让移植任务同时维护两套术语和规则，增加引用错误。

## 后果

- HarmonyOS 任务先读取根目录上下文和 ADR。
- Android 代码只作为行为、协议和功能取证来源。
- 如果未来拆出独立 HarmonyOS feature 或 shared module，再评估是否需要多上下文。

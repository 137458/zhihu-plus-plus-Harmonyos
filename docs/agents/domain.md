# Domain Docs

本仓库采用 single-context 领域文档布局。

## 探索顺序

开始处理 HarmonyOS 任务前，按以下顺序读取：

1. 根目录 `CONTEXT.md`。
2. `docs/adr/` 中与当前页面、数据流、平台 API 或安全边界相关的 ADR。
3. 当前实现和对应测试。
4. `zhihu-plus-plus/` 中的 Android 代码，仅作为行为和协议参考。

## 结构

```text
HarmonyApp/
├─ CONTEXT.md
├─ docs/
│  ├─ adr/
│  └─ agents/
└─ entry/
```

领域术语、模块职责和状态语义以 `CONTEXT.md` 为准。架构决策以 `docs/adr/` 为准；新实现若与已有 ADR 冲突，必须明确指出冲突并更新决策，而不是静默覆盖。

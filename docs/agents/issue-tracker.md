# Issue tracker: GitHub

本仓库的问题、移植批次和 PRD 使用 GitHub Issues 管理，远端仓库由 `gh` CLI 创建和维护。

## 约定

- 创建 Issue：`gh issue create --title "..." --body-file ...`
- 查看 Issue：`gh issue view <number> --comments`
- 列出 Issue：`gh issue list --state open --json number,title,body,labels,comments`
- 评论 Issue：`gh issue comment <number> --body "..."`
- 添加或移除标签：`gh issue edit <number> --add-label "..."` 或 `--remove-label "..."`
- 关闭 Issue：`gh issue close <number> --comment "..."`

使用工程远端配置推断仓库，不在脚本中硬编码其他仓库地址。Issue 内容必须区分已验证现象、待确认事实和实施方案；没有证据时不能把猜测当成产品契约。

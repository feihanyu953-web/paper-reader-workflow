# Paper-Reader Gate Protocol

框架版本：v1.2-route

本文件记录当前项目已经实现的双 Stop gate。它只描述现有机制，不新增 gate、不改变 hook、不改变 reviewer、不改变扫描范围。

## Stop hook 入口

当前 `.claude/settings.json` 在 Stop 阶段运行：

- `.claude/hooks/kb_review_gate.ps1`

本 gate 扫描论文 kb 和 wiki 变更。搭配 `computer-kb-workflow` 使用时会额外注册 computer_kb gate。

## 论文 kb/wiki gate

- Hook：`.claude/hooks/kb_review_gate.ps1`
- 扫描范围：`kb/**/*.md` + `wiki/**/*.md`
- 排除：`kb/REVIEWER_LOG.md`、`kb/.audit/**`
- Reviewer：`kb-independent-reviewer`
- Reviewer 规则：只读；禁止接受工作 AI 缩小审查范围；按 `kb/REVIEWER.md` 输出报告。
- Receipt 脚本：`.claude/scripts/New-AuditReceipt.ps1`
- Receipt schema：`kb_audit_receipt_v1`
- Receipt 记录：`kb_tree_hash` 和 `wiki_tree_hash`
- 结论：论文 `kb/` 与论文 `wiki/` 共用同一个 PASS receipt。

`kb_review_gate.ps1` 会重新计算当前 `kb/**/*.md` 和 `wiki/**/*.md` 的 tree hash，并寻找匹配的 PASS receipt。若没有匹配 receipt，Stop 阶段会 block。

## 修改后的最小流程

修改 `kb/**/*.md` 或 `wiki/**/*.md` 后：

1. 调用 `kb-independent-reviewer`。
2. 修复 BLOCKING 问题。
3. 运行 `.claude/scripts/New-AuditReceipt.ps1`。
4. 将 reviewer 摘要追加到 `kb/REVIEWER_LOG.md`。

Reviewer 只读，不写日志，不写 receipt。工作 AI 在收到 reviewer 报告并完成必要修复后，才负责写入日志和生成 receipt。

## 高安全模式

论文 kb/wiki gate 支持 `kb/.audit/force_external_approval` marker。该 marker 存在时，`kb_review_gate.ps1` 要求 external approval receipt；不存在时使用默认 `workflow_integrity` 模式。

本文件不改变高安全模式触发条件。schema 迁移或 wiki 大规模同步是否进入高安全模式，以 `kb/INDEX.md` 的当前规则为准。批量入库不触发高安全模式。

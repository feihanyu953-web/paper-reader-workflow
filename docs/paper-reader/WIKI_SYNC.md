# Paper-Reader Wiki Sync Protocol

框架版本：v1.2-route

本文件承载论文 wiki/Obsidian 展示层同步规则。修改 `wiki/**/*.md` 前必须读取本文件和 `wiki/index.md`；如果同步来自论文 kb 入库，也必须读取 `kb/INDEX.md`。

## 展示层定位

`wiki/` 是论文知识网络和 Obsidian 展示层，不是独立事实源。

关键数字、谱峰、性能、机理判断必须能追溯到 `kb/*.md` 中的 `schema_v1` 记录。若 wiki 与 kb 或原文冲突，按 `kb/REVIEWER.md` 做三方比对。

不得把未进入 schema 化 kb 的关键数字直接作为概念页事实。若某数字只存在于精读笔记而尚未写入 kb，先补入对应 kb 模块，再让 wiki 引用该数据。

## YAML frontmatter

本节只在当前任务同时包含导出笔记创建或更新时适用。若用户只要求修改 `wiki/**/*.md`，不得因为读取本文件而顺手修改 `已阅读文献/` 下的精读笔记。

需要创建或更新精读笔记时，在笔记 `.md` 文件顶部（标题 `#` 之前）插入结构化元数据。格式参照 `已阅读文献/` 下已有笔记：

```yaml
---
title: "论文中文短语标题"
authors: "第一作者 et al."
year: 2025
journal: "期刊全名"
doi: "DOI"
type: 实验 / 计算 / 实验+计算 / 综述
method: "关键方法"
system: "体系描述"
catalyst: "催化剂"
electrolyte: "电解液"
reaction: "反应类型"
tags:
  - 标签1
  - 标签2
---
```

字段规则：

- `title`、`authors`、`year`、`journal`、`doi`、`type` 必填。
- `method`、`system`、`reaction` 必填。
- `catalyst`、`electrolyte` 对实验或实验+计算论文必填。
- `ΔG_RDS`、`barrier_*` 等计算字段有则填写，值必须包含步骤描述、数值和出处。
- `enhancement`、`FE`、`overpotential` 等实验字段有则填写。
- 所有数值字段必须附带出处，格式如 `"步骤描述: 数值 (Table X, Fig. Y, Section Z)"`。
- `tags` 通常为 2-6 个标签，用于 Obsidian 图谱分组。
- 若论文类型无法适配某字段，直接省略，不填占位符。

## 关联概念标签

本节只在当前任务同时包含导出笔记创建或更新时适用。若用户只要求修改 `wiki/**/*.md`，不得因为读取本文件而顺手修改 `已阅读文献/` 下的精读笔记。

论文知识库与计算知识库在 Obsidian 图谱中保持独立。论文笔记的关联概念只指向 `wiki/concepts/`；不得为了连通图谱而链接 `computer_kb/wiki/`、`computer_kb/records/` 或计算知识库的 workflow/error 页面。论文中的 DFT/AIMD/MLFF/MD 信息应进入 `kb/methods.md` 和论文侧概念页，不创建“计算关联”小节。

在笔记末尾（`## 附录` 之前或最后一行之后）追加：

```markdown
## 关联概念

- [[概念A]] · [[概念B]] · [[概念C]]
```

规则：

- 标签指向 `wiki/concepts/` 下已有概念页，使用文件名，不含路径和扩展名。
- 标签不得指向 `computer_kb/wiki/` 下的页面；两个知识库只在回答用户问题时由 AI 综合检索，不在 Obsidian wikilink 图谱中强制互联。
- 若现存概念页无法覆盖本文核心概念，先按 concept 聚合页规则创建概念页，再引用。
- 一篇论文通常 3-6 个概念标签。

## concept 聚合页

检查本次精读或入库的数据是否影响 `wiki/concepts/` 下已有概念页：

- 有影响：在相关概念页追加本文的新数据点、矛盾标记（`[!contradiction]`）或佐证信息，并链接回笔记（`[[笔记文件名]]`）。
- 新概念：创建 `wiki/concepts/<新概念>.md`，格式参照已有概念页，至少包含定义、关键数据、关联论文表和开放问题。
- 无影响：跳过，不为了形式新建概念页。

概念页中的关键事实必须能回到 `kb/` 的 schema 记录。已导出的精读笔记只能作为补充阅读入口或 Obsidian 反链，不得作为关键数字、谱峰、性能、机理判断的唯一事实来源。

## wiki/index.md 更新

按 `wiki/index.md` 的现有结构更新展示层索引：

- 在按子领域导航中更新概念页和论文数。
- 在按论文导航表中追加或修正论文条目。
- 在 Stub 论文表中移除已完成精读的 stub 或更新状态。
- 在实体索引中追加真实实体关系，不添加空泛实体。

同时更新 `wiki/log.md`，追加操作记录：

```markdown
| 日期 | ingest | 论文标题 | 更新了哪些概念页 |
```

## 与 kb schema 记录的追溯关系

`wiki/` 中的关键数字和机理判断必须能追溯到 `kb/SCHEMA.md` 约定的 schema 化记录。

同步时至少检查：

- 论文是否已在 `kb/literature.md` 建立索引。
- 性能数据是否进入 `kb/performance.md`。
- 谱图和峰位是否进入 `kb/spectra.md`。
- 机理路径、自由能、描述符是否进入 `kb/mechanism.md`。
- 方法参数、DFT/MD/MLFF 设置是否进入 `kb/methods.md`。
- 合成细节是否进入 `kb/synthesis.md`。

如果某类数据原文没有，必须在 kb 侧按规则标注“原文未说明”或“不适用”，不能在 wiki 侧绕过。

## 完成后的门禁

`wiki/**/*.md` 由论文 kb/wiki gate 扫描，与 `kb/**/*.md` 共用同一个 PASS receipt。修改任何 `wiki/**/*.md` 后，必须读取：

- `docs/paper-reader/GATES.md`
- `kb/REVIEWER.md`

并走固定只读 reviewer `kb-independent-reviewer` 与 `.claude/scripts/New-AuditReceipt.ps1`。

不得使用 `computer_kb` gate 替代论文 kb/wiki gate。

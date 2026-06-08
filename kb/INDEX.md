# 电催化知识库 · 总索引

> 当前数据层采用 `kb/SCHEMA.md` 的 `schema_v1` 字段契约。后续新增、补充、迁移的 kb 条目必须写入 schema 化记录，不再新增旧格式表格。`wiki/` 是展示层，关键数字和机理判断必须能追溯到 schema 化 kb 条目。

## 工作模式

本知识库支持两种论文处理模式：

| | 精读模式 | 批量入库 |
|---|---|---|
| 触发词 | "导出"/"编译笔记"/"生成PDF" | "批量导入" |
| 内部流程 | pdftotext → Step 0.2 出处映射 → 10 板块分析 → 编译 MD → 导出 PDF → kb 入库 + wiki 同步 + reviewer | **同精读**：pdftotext → Step 0.2 出处映射 → 6 子领域深挖模块全部执行 → kb 入库 |
| 用户可见输出 | 完整 10 板块笔记 + MD 文件 + PDF + kb 入库摘要 | **无**：不输出板块笔记，不生成 MD，不导出 PDF |
| kb 追加 | ✅ 6 模块，按 `SCHEMA.md` 写入 `schema_v1` | ✅ 6 模块，按 `SCHEMA.md` 写入 `schema_v1` |
| 完成后告知 | 完整笔记 + 导出路径 + wiki 同步摘要 + reviewer 结果 | 每篇一行汇总（标题 + 作者 + 入了多少个模块条目） |

### 批量入库规则

**数据质量与精读模式完全一致**——内部必须完整走 pdftotext → 出处映射 → 6 深挖模块检查点，每条数据标注 Fig./Table/Section。唯一区别是不向用户输出 10 板块内容、不编译 MD、不导出 PDF。

所有入库结果必须追加为 `schema_v1` 记录。若原文或旧条目未载明某字段，写 `原条目未载明，需回原文核对`，不得编造字段值。

每篇完成后仅告知：`[N/M] Author (Year) — 入了 X 条合成 + Y 条性能 + Z 条谱图 + W 条机理 + V 条方法`

### 任务完成前强制对账

声称"批量入库完成"前，工作 AI **必须**执行以下对账：

1. 读取 `literature.md` → 统计论文索引总数 N
2. 逐篇核验：每篇非综述论文是否 ≥5/6 模块有数据条目
3. 未达标的论文 → 列出清单 → 继续处理该论文 → 回到步骤 2
4. 论文类型天然不适用某模块 → 必须给出"原文经扫描，Section X 无此数据"证据
5. 全部论文达标后 → 方可 spawn 评审员做最终审计

> 此规则保证评审员介入前，工作 AI 已完整处理全部源论文，而非中途停止。

### SI 自动处理

文件名约定：正文 `xxx_main.pdf`，SI `xxx_SI.pdf`，放在同一文件夹下。

处理规则：
- 检测到 `_main.pdf` 时自动扫描同目录下对应 `_SI.pdf`，有则一并提取
- SI 只提取以下三类内容（跳过推导、额外讨论、重复表格）：
  1. **合成细节**：前驱体用量、洗涤步骤、热解升温速率等正文未载明的细节
  2. **表征数据**：XRD 峰位、TEM 粒径分布、XPS 结合能、Raman/IR 峰位、XAS 参数等
  3. **计算参数**：k-points、slab 层数、U 值、泛函、溶剂模型、MLFF 训练细节等
- SI 提取的数据统一标注 `[SI, Fig. Sx]` 出处

> **质量门禁**：任何修改 kb/wiki 文件的操作（Edit/Write/MultiEdit）后，必须调用项目级固定 reviewer：`kb-independent-reviewer`。不得使用 `general-purpose` 临时子代理替代，不得由主 AI 自行编写审查 prompt。Reviewer 只读，协议见 `kb/REVIEWER.md`。Reviewer 输出报告后，由主 AI 追加 `kb/REVIEWER_LOG.md`，Reviewer 自身禁止写日志。

### 高安全模式触发条件

以下场景必须在操作前创建 `kb/.audit/force_external_approval` marker，强制进入外部审批模式：

- kb schema 版本迁移（如 schema_v1 → schema_v2）
- wiki/ 大规模同步（一次性修改 ≥5 个概念页的定义或分类框架）

marker 存在时，`kb_review_gate.ps1` 要求 `external_approval` receipt。外部审批由用户在独立终端中运行 `.claude/scripts/approve_kb_audit.ps1`，审阅变更文件清单和 tree hash 后确认。

marker 的创建与清理：

```powershell
# 操作前创建
New-Item -ItemType File -Path "kb/.audit/force_external_approval"

# 外部审批完成后删除
Remove-Item "kb/.audit/force_external_approval"
```

**不在触发范围内的操作**（使用默认 `workflow_integrity` 模式，不创建 marker）：

- 精读入库（单篇）
- 批量入库（无论篇数，操作类型为追加 schema 记录，不改变数据结构）
- 常规 wiki 概念页追加或更新（不影响分类框架或定义）

## 路由规则

| 用户问题涉及 | 路由至 |
|---|---|
| 催化剂合成、前驱体、热解温度、水热、沉积、掺杂、载体、酸洗、负载量 | `synthesis.md` |
| FE、电流密度、Tafel 斜率、ECSA、TOF、产率、稳定性、空白对照、同位素验证 | `performance.md` |
| Raman、IR/SEIRAS/SFG、XPS、XAS(XANES+EXAFS)、DEMS、NMR、GC/HPLC、EPR、UV-vis、MS 峰位归属 | `spectra.md` |
| 反应路径、决速步、中间体、描述符(d-band/Bader/ICOHP)、自由能图、PCET、协同效应 | `mechanism.md` |
| 测试构型(H-cell/flow/GDE/MEA)、iR 补偿、参考电极换算、Slab/泛函选择、MLFF 训练策略 | `methods.md` |
| 已读论文索引、分类框架、种子论文、关键数字速查 | `literature.md` |
| 追问与讨论、概念理解、判断推理 | `qa.md` |
| 多个模块同时涉及 | 按需读取全部相关模块，整合回答 |

## 通用参考骨架

`reference/` 目录预置领域公认参考数据（标准 Raman 峰位、XPS 结合能等），每条标注出处。文献值与参考值冲突时并列呈现，不掩盖。

| 文件 | 内容 |
|---|---|
| `reference/common_raman.md` | 电催化常见 Raman 峰位归属 |
| `reference/common_ir.md` | 电催化常见红外特征峰 |
| `reference/common_xps.md` | 常见元素 XPS 结合能参考 |

## 数据格式约定

每条知识记录必须遵守 `kb/SCHEMA.md`。通用必填字段：

- `record_id`
- `schema_version`
- `paper_id`
- `module`
- `category`
- `subject`
- `metric`
- `value`
- `unit`
- `condition`
- `source`
- `confidence`
- `note`

来源标注格式：`[Author Year, Journal, Fig. X]` 或 `[Author Year, Section/Table/SI]`。每一行必须有 `source`，不能只在段落末尾笼统标注。

## 审计日志

每次精读入库、批量入库、schema 迁移、wiki 同步或修复循环结束后，主 AI 必须在 `kb/REVIEWER_LOG.md` 追加记录，至少包含：

- 任务类型
- 涉及论文或文件
- 修改的 kb/wiki 文件
- Reviewer 轮次与 PASS/FAIL/WARNING
- 修复项与最终状态
- 延后处理的 NON-BLOCKING 项

## 模块摘要

### synthesis.md
催化剂合成配方、条件、前驱体处理。条目数取决于已导入论文量

### performance.md
电催化性能数据（FE/j/Tafel/稳定性等）。条目数取决于已导入论文量

### spectra.md
谱图峰位归属（Raman/IR/XPS/XAS/DEMS 等）。条目数取决于已导入论文量

### mechanism.md
反应机理通路、决速步、中间体、描述符。条目数取决于已导入论文量

### methods.md
测试与计算方法参数。条目数取决于已导入论文量

### literature.md
已读论文索引、分类框架、种子论文。条目数取决于已导入论文量

### qa.md
追问与概念理解。条目数取决于已导入论文量

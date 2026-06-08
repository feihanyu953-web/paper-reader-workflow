# Paper-Reader Batch Ingest Protocol

框架版本：v1.2-route

本文件承载批量论文导入的调度协议。主 AI 在用户触发批量导入时，必须先读取本文件、`kb/INDEX.md` 和 `docs/paper-reader/READING.md`。若涉及 wiki 同步，还需读取 `docs/paper-reader/WIKI_SYNC.md`。

本协议的核心原则：**子 agent 只读论文并产出结构化中间结果，主 AI 是唯一的写库者**。不改动现有的 reviewer、gate script 或 receipt 机制。

---

## 1. 触发条件

用户说"批量导入 N 篇论文"（N ≥ 2）时，主 AI 进入批量导入模式。

| 触发词 | 模式 | 用户可见输出 |
|---|---|---|
| "批量导入" / "批量入库" | 批量导入 | 每篇一行汇总 + 审计结果 |
| "导出" / "编译笔记" / "生成PDF" | 精读模式（单篇）| 完整 10 板块笔记 + MD + PDF |

当 N = 1 时，降级为精读模式（走 `READING.md` 完整流程），不启动批量调度。

---

## 2. 分片策略

**分片规则**：`agent_count = ceil(N / 2)`，每个 agent 处理 1-2 篇论文。

```
N=2  → 1 agent  (Paper 1, 2)
N=3  → 2 agents (Agent A: Paper 1,2; Agent B: Paper 3)
N=4  → 2 agents (Agent A: Paper 1,2; Agent B: Paper 3,4)
N=5  → 3 agents (Agent A: Paper 1,2; Agent B: Paper 3,4; Agent C: Paper 5)
N=6  → 3 agents (Paper 1,2 / 3,4 / 5,6)
...
```

**理由**：1 篇浪费 spawn 开销，3 篇开始出现注意力衰减。2 篇/agent 是精读质量与并行效率的平衡点。

---

## 3. 子 Agent 约束（CRITICAL）

子 agent 是通用 agent + 标准化 prompt，不是固定角色 agent。每个子 agent 拥有完全独立的上下文，只看到自己的 prompt 和分配的论文，不继承主会话历史。

### 3.1 允许的操作

- 读取论文全文（PDF、SI、pdftotext 输出、Zotero 全文索引、OCR 管道）
- 按 `READING.md` Step 0.2 建立出处映射（source_map）
- 按 6 个子领域深挖模块扫描全文，提取 schema 候选记录
- 读取 `docs/paper-reader/READING.md`、`kb/SCHEMA.md`（仅用于理解输出格式要求）
- 返回结构化中间结果（见第 5 节模板）

### 3.2 禁止的操作

- **禁止写 `kb/**`、`wiki/**`、`REVIEWER_LOG.md`**
- **禁止生成 receipt**（receipt 由主 AI 在审计完成后统一生成）
- **禁止分配 `record_id`**（统一填 `"TBD-by-main"` sentinel）
- **禁止 invoke reviewer agent**（`kb-independent-reviewer`、`computer-kb-independent-reviewer`）
- **禁止写 `已阅读文献/` 下任何文件**（精读笔记、stub、YAML frontmatter 均不创建）
- **禁止修改 `CLAUDE.md`、`MEMORY.md`、配置文件或 hook 脚本**

违反以上任何一条的子 agent 输出，主 AI 必须整批拒绝，重新 spawn。

---

## 4. 执行器适配阅读规则

不同执行环境对 PDF 阅读的支持不同。子 agent prompt 中必须根据当前执行器类型嵌入对应的阅读策略：

### 4.1 Claude Code / deepseek-v4

```
阅读策略：文本管道优先
  1. pdftotext -layout "PDF路径" -（提取全文文本）
  2. 若 PDF 同目录存在 .zotero-ft-cache → 作为补充索引
  3. 若 pdftotext 失败（扫描件）→ pdftoppm + tesseract OCR 管道
  4. SI PDF 同规则处理

关键约束：
  - 不支持原生 PDF 视觉理解，不得依赖 Read 工具读 PDF
  - 所有数据必须从文本管道中定位
  - source_map 中的 Fig./Table 编号从 pdftotext 输出中提取
```

### 4.2 Codex / GPT-5.5

```
阅读策略：原生 PDF 优先 + pdftotext 辅助
  1. 优先使用原生 PDF/视觉理解能力覆盖正文、图、表、谱图和 SI
  2. pdftotext 作为辅助工具：关键词检索、表格文本比对、出处证据复制
  3. 原生视觉无法稳定定位 Fig./Table/Section 时，用 pdftotext 确认编号

关键约束：
  - 原生视觉阅读后仍需建立 source_map
  - 关键数字必须能定位到 Fig./Table/Section 编号
```

子 agent prompt 中由主 AI 根据当前执行器填入对应的阅读策略段（见第 9 节模板中的 `{executor_reading_rules}` 占位符）。

---

## 5. 中间结果格式

子 agent 必须返回以下结构化 YAML-like 中间结果。每个 agent 处理 N 篇论文时，返回 N 个独立的结果块，用 `---` 分隔。

### 5.1 完整模板

```yaml
paper_id: "AuthorYear"  # 短标识，如 Shen2026、Wang2021_ORR
title: "完整论文标题"
evidence_status: "full_text"  # full_text / abstract_only / access_limited

# ===== 出处映射表（最关键，不可省略）=====
source_map:
  - claim_or_data: "具体数据或机理描述"
    source: "Fig. X / Table Y / Section Z.Z / SI Fig. Sx"
  - claim_or_data: "另一条数据"
    source: "Fig. X, Section Y.Y 第 N 段"

# ===== 模块覆盖状态 =====
module_coverage:
  synthesis: covered | not_applicable | missing
  performance: covered | not_applicable | missing
  spectra: covered | not_applicable | missing
  mechanism: covered | not_applicable | missing
  methods: covered | not_applicable | missing
  literature: covered | not_applicable | missing

# ===== Schema 候选记录（按 6 模块分组）=====
schema_candidates:
  synthesis:
    - record_id: "TBD-by-main"
      paper_id: "AuthorYear"
      module: "synthesis"
      category: "合成类别"
      subject: "催化剂/材料名称"
      metric: "数据项名称"
      value: "具体数值或描述"
      unit: "单位"
      condition: "合成条件（温度/时间/气氛/方法）"
      source: "[Author Year, Journal, Fig. X / Table Y / Section Z]"
      confidence: "single_source | multi_source | verified"
      note: "补充说明"

  performance:
    - record_id: "TBD-by-main"
      paper_id: "AuthorYear"
      module: "performance"
      category: "性能类别"
      subject: "催化剂 + 反应"
      metric: "FE | j | Tafel | TOF | stability | yield | selectivity | ..."
      value: "数值"
      unit: "% | mA cm^-2 | mV dec^-1 | h | mmol h^-1 gcat^-1 | ..."
      condition: "电位 / 电解液 / 电池构型 / 底物浓度"
      source: "[Author Year, Journal, Fig. X / Table Y / Section Z]"
      confidence: "single_source | multi_source | verified"
      note: "补充说明"

  spectra:
    - record_id: "TBD-by-main"
      paper_id: "AuthorYear"
      module: "spectra"
      category: "谱图类别"
      subject: "材料/体系/中间体"
      metric: "技术 + 峰/信号 (Raman peak | XPS BE | m/z | EXAFS CN | ...)"
      value: "峰位/结合能/m/z/键长/配位数"
      unit: "cm^-1 | eV | m/z | Å | 无"
      condition: "原位条件 / 电位 / 光照 / 反应物"
      source: "[Author Year, Journal, Fig. X / Table Y / Section Z]"
      confidence: "single_source | multi_source | verified"
      note: "补充说明"

  mechanism:
    - record_id: "TBD-by-main"
      paper_id: "AuthorYear"
      module: "mechanism"
      category: "机理类别"
      subject: "反应路径 / 活性位 / 描述符 / 中间体"
      metric: "RDS | barrier | ΔG | adsorption_mode | descriptor | evidence"
      value: "数值或路径描述"
      unit: "eV | Å | 无"
      condition: "模型 / 表面 / 电解质 / 反应条件"
      source: "[Author Year, Journal, Fig. X / Table Y / Section Z]"
      confidence: "single_source | multi_source | verified"
      note: "补充说明"

  methods:
    - record_id: "TBD-by-main"
      paper_id: "AuthorYear"
      module: "methods"
      category: "方法类别"
      subject: "方法 / 构型 / 计算设置 / 表征方案"
      metric: "cell_type | reference_electrode | functional | k-points | slab | probe | reactor | ..."
      value: "参数值"
      unit: "物理单位或 无"
      condition: "适用体系或用途"
      source: "[Author Year, Journal, Fig. X / Table Y / Section Z]"
      confidence: "single_source | multi_source | verified"
      note: "补充说明"

  literature:
    - record_id: "TBD-by-main"
      paper_id: "AuthorYear"
      module: "literature"
      category: "已读论文索引"
      subject: "论文标题"
      metric: "core_contribution | sub_field | paper_type | key_numbers | reading_status"
      value: "结构化描述"
      unit: "无"
      condition: "研究方向或反应体系"
      source: "[Author Year, Journal, 整体]"
      confidence: "verified"
      note: "类型: 实验/计算/实验+计算/综述; 子领域: ...; 精读状态: 批量入库"

# ===== Wiki 同步候选 =====
wiki_sync_candidates:
  concepts_to_update: ["概念A", "概念B"]    # 仅限论文侧 wiki/concepts/，不得指向 computer_kb/wiki
  concepts_to_create: []                      # 仅在论文侧 wiki/concepts/ 新建可复用概念页
  paper_stub_needed: false                    # 是否需要生成 stub 笔记

# ===== 缺失数据证据 =====
missing_data_evidence:
  - module: "synthesis"
    statement: "原文经扫描，Methods / Experimental Section X.X 仅含表征方法与电化学测试步骤，无催化剂合成数据。该论文使用商业催化剂（如 Sigma-Aldrich Pt/C），故 synthesis 模块标记为 not_applicable"
  - module: "spectra"
    statement: "原文经扫描，全文（含 SI）无 Raman、IR、XPS、XAS 或 DEMS 表征。Section 3 的讨论仅基于 DFT 计算和电化学数据"

# ===== 风险标记 =====
risk_flags:
  - none
  # 可选值: duplicate_possible, source_uncertain, access_limited, requires_cross_reference, review_paper_compiled_data
```

### 5.2 格式铁律

- `source_map`：每条 `claim_or_data` 必须精确对应一个 `source`（Fig./Table/Section 编号），不可多条数据共用一个笼统来源
- `schema_candidates`：每条候选记录必须有 `source` 字段，值包含 Fig./Table/Section
- `record_id`：统一填 `"TBD-by-main"`，由主 AI 在写入阶段统一分配
- `missing_data_evidence`：不能写笼统的"原文未说明"，必须注明**具体扫描了哪个 Section 确认无此数据**。格式：`"原文经扫描，[具体 Section / SI 章节] [具体发现]"`
- `confidence`：`single_source`（仅本论文）、`multi_source`（本论文多处或跨论文多源）、`verified`（经三方比对确认）、`conflict`（与已有数据冲突）

---

## 6. 主 AI 职责

主 AI 不亲自做精读，只做调度、质量门禁、分批写入和审计协调。

### Step 0：读取规则

```
1. 读取本文档（docs/paper-reader/BATCH.md）
2. 读取 kb/INDEX.md
3. 若涉及 wiki 同步：读取 docs/paper-reader/WIKI_SYNC.md
4. 读取 kb/SCHEMA.md（用于后续写入时字段校验）
```

### Step 1：分片与调度

```
1. 收集用户提供的 N 篇论文（PDF 路径 / DOI / 标题列表）
2. 按 ceil(N/2) 确定 agent 数量
3. 为每篇论文确定执行器适配阅读策略（4.1 或 4.2）
4. 为每个 agent 组装自包含 prompt（使用第 9 节模板）
5. 并行 spawn 所有 agent
```

每个 agent prompt 必须是**自包含的**：包含论文 PDF/SI 路径、READING.md 核心规则摘要、6 模块检查点、中间结果输出模板、执行器适配阅读规则、禁止事项清单。Agent 不继承主会话上下文。

### Step 2：Agent 并行读取与提取

所有 agent 同时运行。主 AI 等待全部 agent 返回中间结果。

Agent 内部流程：
```
1. 读取论文全文（按执行器适配规则）
2. 建立 source_map（数据/机理 → Fig./Table/Section 映射）
3. 按 6 个子领域深挖模块扫描全文
4. 提取 schema_candidates（按 SCHEMA.md 字段格式）
5. 标记 module_coverage + missing_data_evidence
6. 返回结构化中间结果
```

### Step 3：质量门禁（不可跳过）

主 AI 对每个 agent 返回的中间结果执行以下检查：

#### 3a. source_map 完整性

- [ ] 每篇论文返回了 source_map
- [ ] source_map 条目数 ≥ 5（至少覆盖性能数据、方法参数、机理判断、表征数据等核心数据类型）
- [ ] 每条 claim_or_data 有唯一对应的 source（Fig./Table/Section）
- [ ] 无多条数据共用一个笼统 source 的情况

#### 3b. module_coverage 覆盖率

- [ ] 非综述论文：≥5/6 模块标记为 `covered`
- [ ] 标记为 `not_applicable` 的模块：对应 `missing_data_evidence` 中有明确证据（注明扫描了哪个 Section）
- [ ] 标记为 `missing` 的模块：说明原因（不能仅写"未提取"）
- [ ] 纯计算论文：synthesis 可 `not_applicable`，但 methods/mechanism 必须 `covered`
- [ ] 纯实验论文：mechanism 中的计算部分可 `not_applicable`，但 performance/spectra 必须 `covered`

#### 3c. schema_candidates 逐条检查

- [ ] 每条候选记录有 `source` 字段，值包含 Fig./Table/Section
- [ ] `record_id` 均为 `"TBD-by-main"`
- [ ] `value` 和 `unit` 已拆分（可拆分时）；无法拆分时在 `note` 中说明
- [ ] 无空值字段（除 `note` 外）
- [ ] `confidence` 取值合法

#### 3d. missing_data_evidence 质量

- [ ] 每条证据注明扫描了哪个 Section
- [ ] 不使用笼统的"原文未说明"
- [ ] 不用于掩盖 agent 偷懒（应 covered 但标了 not_applicable）

#### 判定与处理

```
全部达标 → 进入 Step 4
任一不达标 → 拒绝该 agent 整批结果 → 重新 spawn（更严格 prompt 或换模型）
  重试 1 次仍不达标 → 降级为主 AI 亲自精读该篇论文（按 READING.md 完整流程）
  降级处理的论文：主 AI 需产出与其他 agent 同格式的中间结果 + 原始精读笔记
```

### Step 4：分批写入

主 AI 是唯一的写库者。按每 3 篇论文为一批，串行写入。

```
Batch 1: Paper 1-3
  4a. 统一分配 record_id（从 kb 各模块现有最大 ID + 1 开始）
  4b. 去重检查：与 literature.md 已有索引比对，同论文重复入库按 kb/REVIEWER.md 维度 0 处理
  4c. 合并跨 agent 重复数据（如同一数据点出现在多篇论文中）
  4d. 写入 kb/ 6 模块（追加 schema_v1 记录，不覆盖已有条目）
  4e. 更新 kb/literature.md 论文索引
  4f. 同步 wiki/（按 WIKI_SYNC.md）：更新概念页 + 必要时新建概念页 + 更新 wiki/index.md + wiki/log.md

Batch 2: Paper 4-6
  ...（同上）

Batch K: Paper N-2 ~ N
  ...
```

**写入规则**：

- 每条新增记录使用 `schema_v1` 格式，13 字段齐全
- `record_id` 由主 AI 全局统一编号，格式 `module-NNNN`（如 `mechanism-0205`）
- `confidence` 初始值：单篇论文提取 → `single_source`；多篇论文共同支持同一数据点 → `multi_source`
- 去重合并时，在 `note` 中标注 `[双次验证]` 或 `[多源验证: Paper1, Paper2]`
- 冲突数据不直接覆盖，并列写入并标记 `⚠️ CONFLICT`
- 论文类型天然不适用某模块 → 不在该模块写入记录，在 `literature.md` 的 note 中备注

**wiki 同步规则**（按 WIKI_SYNC.md）：

- 概念页追加新数据点时，必须链接回 `literature.md` 中的论文索引行
- 概念页中的关键数字必须可追溯到 kb schema 记录
- 新建概念页格式：定义 + 关键数据 + 关联论文表 + 开放问题
- `wiki/index.md` 在论文导航表中追加每篇新论文
- `wiki/log.md` 追加操作记录

### Step 5：分批审计

每批 3 篇写入完成后，立即 spawn `kb-independent-reviewer` 进行审计。

```
Batch 1 写入完成 → spawn reviewer（只读）→ 接收报告 → 修复 BLOCKING 项 → New-AuditReceipt.ps1 (receipt_1)
Batch 2 写入完成 → spawn reviewer（只读）→ 接收报告 → 修复 BLOCKING 项 → New-AuditReceipt.ps1 (receipt_2)
...
Batch K 写入完成 → spawn reviewer（只读）→ 接收报告 → 修复 BLOCKING 项 → New-AuditReceipt.ps1 (receipt_K, 最终)
```

**Reviewer 调用规范**：

- 使用项目固定 reviewer：`kb-independent-reviewer`（sonnet 模型，只读：Read/Glob/Grep/Bash）
- 不得使用 `general-purpose` 临时子代理替代
- 不得由主 AI 自行编写审查 prompt 或缩小审查范围
- 主 AI 向 reviewer 提供：
  - 任务类型：批量导入
  - 本批处理的论文列表和 pdftotext 输出路径
  - 本批修改的 kb 模块文件路径
  - 本批修改的 wiki 概念页路径
  - 提示：若论文为综述，标注哪些 Table 含编译数据
- reviewer 必须按 `kb/REVIEWER.md` 对**当前完整 kb/wiki tree** 做独立审查（不受"本批新增"范围限制）
- 每批审计后，receipt 按**当前完整 kb/wiki tree hash** 生成，不是按批次局部 hash

**修复循环**：

- 最多 3 轮（初始 + 2 次修复）
- 第 3 轮仍 FAIL 的 BLOCKING 项 → 告知用户，由用户裁决
- 第 3 轮仍 FAIL 的 NON-BLOCKING 项 → 记录到 `kb/REVIEWER_LOG.md`，生成 FAIL receipt（标记已知风险）
- 每轮修复后重新 spawn reviewer

**审计后操作**：

- 追加 `kb/REVIEWER_LOG.md`（主 AI 执行，reviewer 禁止写日志）
- 调用 `.claude/scripts/New-AuditReceipt.ps1` 生成 receipt
- 若 PASS：`New-AuditReceipt.ps1`（默认 verdict = PASS）
- 若 FAIL 但已知风险：`New-AuditReceipt.ps1 -Verdict FAIL`

**Receipt 管理**：

- 每批审计后生成一个新 receipt
- 只有最后一个 batch 的 receipt 对应最终 kb/wiki tree hash
- 前序 receipt 成为历史废弃品（不影响 Stop hook）
- Stop hook 只匹配当前 tree hash，不受历史 receipt 影响

### Step 6：最终对账

全部批次完成后，执行最终对账：

```
1. 读取 kb/literature.md → 确认本次 N 篇论文全部已建索引
2. 逐篇核验：每篇非综述论文是否 ≥5/6 模块有 schema_v1 条目
3. 未达标 → 列出清单 → 继续处理 → 回到步骤 2
4. 全部达标 → 检查最终 receipt 是否匹配当前 kb/wiki tree hash
5. 向用户输出完成摘要
```

**完成告知格式**：

```
批量导入完成：N/N 篇全部入库

[1/N] Author (Year) — 入了 X 条合成 + Y 条性能 + Z 条谱图 + W 条机理 + V 条方法
[2/N] Author (Year) — 入了 X 条合成 + Y 条性能 + Z 条谱图 + W 条机理 + V 条方法
...
[N/N] Author (Year) — 入了 X 条合成 + Y 条性能 + Z 条谱图 + W 条机理 + V 条方法

wiki 同步：概念页 [A, B, C] 已更新，新建概念页 [D, E]
reviewer log：已追加 kb/REVIEWER_LOG.md
audit receipt：已生成 kb/.audit/receipts/receipt_*.json
最终评审：PASS ✓
```

---

## 7. 防偷懒检查点

主 AI 在 Step 3 质量门禁中，对每个 agent 输出必须执行以下强制检查。任一不通过即整批拒绝。

### 7.1 必含字段

- [ ] 每篇论文返回了 `source_map`（至少 5 条映射）
- [ ] 每篇论文返回了 `module_coverage`（6 个模块全部标注状态）
- [ ] 每篇论文返回了 `schema_candidates`（至少 1 个模块有候选记录）
- [ ] 综述论文：额外检查分类框架是否完整提取（所有类别独立列出）

### 7.2 schema_candidates 逐条检查

- [ ] 每条候选记录有 `source` 字段，值包含 Fig./Table/Section 编号
- [ ] `source` 不是笼统的段落末尾来源（如 `[Author Year, Journal]` 无具体位置）
- [ ] `value` 和 `unit` 已尽力拆分
- [ ] 无编造的字段值（抽查可疑数字并与 source_map 比对）

### 7.3 missing_data_evidence 质量

- [ ] 不使用笼统的"原文未说明"
- [ ] 每条证据注明扫描了哪个具体 Section / SI 章节
- [ ] 格式：`"原文经扫描，[Section X.X / SI Section Y]，[具体发现]"`
- [ ] `not_applicable` 判定有 evidence 支撑，非简单跳过

### 7.4 不达标的处理

```
不达标 → 拒绝该 agent 整批结果 → 记录拒绝原因
  → 重新 spawn（更严格 prompt：在禁止事项清单中加入具体违规项）
  → 或换模型（如 deepseek → sonnet）
  
重试 1 次仍不达标 → 降级为主 AI 亲自精读该篇
  主 AI 按 READING.md 完整流程处理：pdftotext → 出处映射 → 10 板块 → 提取 schema_candidates
  降级处理的论文与其他 agent 的合格结果合并，进入 Step 4 分批写入
```

---

## 8. 安全模式

**批量导入使用 `workflow_integrity` 模式（低安全默认）。**

- 不创建 `kb/.audit/force_external_approval` marker
- 安全模式判断依据是 `kb/INDEX.md` 的当前规则，不由 BATCH.md 自行定义
- 批量导入（无论篇数多少）属于"追加 schema 记录，不改变数据结构"的操作类型，不触发高安全模式
- 若未来 `kb/INDEX.md` 修改了安全模式触发条件，以 `kb/INDEX.md` 的最新规则为准

高安全模式触发条件由 `kb/INDEX.md` 定义（当前仅包括：kb schema 版本迁移、wiki 大规模同步 ≥5 个概念页定义变更）。批量导入不在其中。

---

## 9. 子 Agent Prompt 模板

以下模板由主 AI 在 Step 1 时为每个 agent 组装。`{placeholder}` 由主 AI 填入实际值。

```
你是一个电催化论文精读 agent。你的任务：阅读分配给你的 1-2 篇论文，按指定格式产
出结构化中间结果。

## 执行器与阅读规则

{executor_reading_rules}

## 你的身份

电催化与计算电化学方向研究者（研究生/博后水平）。同行语气，中文输出，专有名词
保留英文。默认不解释过电位、Tafel、d-band、PBE、RDF 等基础概念。新方法/新泛函/
新表征出现时必须详细讲原理。

## 分配给你的论文

论文 1：
  - PDF 路径：{paper_1_pdf_path}
  - SI 路径：{paper_1_si_path}（若无则写"无"）
  - 论文标识：{paper_1_id}（如 Shen2026）

论文 2（若仅 1 篇则删除此段）：
  - PDF 路径：{paper_2_pdf_path}
  - SI 路径：{paper_2_si_path}
  - 论文标识：{paper_2_id}

## 你必须执行的步骤

### 1. 阅读全文

按上方的执行器适配规则，完整阅读每篇论文的正文和 SI。不得只读摘要或截断前几页。

### 2. 建立出处映射 (source_map)

通读全文时，建立"数据/机理 → Fig./Table/Section"映射表：
  - 每个关键数字（FE、势垒、ΔG、电流密度、键长、MAE、模拟时长等）→ Fig./Table/Section
  - 每个机理描述（反应路径、决速步、中间体、电子结构等）→ 原文位置
  - 每个方法学判断（新泛函、新 MLFF 架构、新原位数技术等）→ 方法/结果/讨论段
  - SI 数据标注 [SI, Fig. Sx]

### 3. 按 6 个子领域模块扫描全文

对每篇论文，按以下 6 个模块逐模块扫描并提取数据。每条数据必须标注原文出处
(Fig./Table/Section/SI)。

**synthesis（合成）**:
  - 催化剂组分、前驱体、合成方法(水热/电沉积/热解/浸渍)
  - 温度、时间、气氛、洗涤步骤、负载量
  - 形貌描述(TEM/SEM/HAADF)、ECSA 测定方式

**performance（性能）**:
  - FE、current density (j)、产率、Tafel 斜率、TOF
  - 过电位、稳定性时长 + 衰减率
  - 电解液(种类/浓度/pH/阳离子)、测试构型(H-cell/flow cell/MEA/GDE)
  - 选择性、副反应抑制、空白对照、同位素证据
  - 产物定量方法(GC/HPLC/NMR/IC)及检出限

**spectra（谱图表征）**:
  - Raman/IR 峰位(cm⁻¹)及归属
  - XPS 结合能(eV)及化学态归属
  - XAS(XANES 边前峰/白线峰 + EXAFS CN/R/σ²)
  - DEMS m/z 信号、NMR 化学位移、EPR g 值
  - 原位条件(电位/气氛/光照)下的谱图变化

**mechanism（机理）**:
  - 完整反应路径(反应物→中间体→产物每一步)
  - 决速步(RDS)及势垒(eV)
  - 自由能图(ΔG 各步数值)
  - 描述符(d-band center/eV、Bader charge/|e|、ICOHP/eV、eg 占据等)
  - 吸附能(eV)、吸附模式、PCET 步骤
  - C-N 偶联步(若适用)：偶联中间体对、协同效应

**methods（方法）**:
  - 电化学：电池构型、参比电极及换算、iR 补偿%、工作电极制备
  - DFT：软件(VASP/CP2K/QE)、泛函+D3、slab 层数、真空层、k-points
  - DFT：Hubbard U 值及依据、溶剂模型(CHE/VASPsol/显式)、NEB/CI-NEB
  - MLFF：架构(DeePMD/MACE/NequIP)、训练集来源/规模、主动学习策略
  - MLFF：能量/力 MAE/RMSE、模拟时长、增强采样方法、PMF CV 选取

**literature（文献索引）**:
  - 论文核心贡献(一句话)
  - 子领域、论文类型(实验/计算/实验+计算/综述)
  - 关键数字摘要(FE 最高值、ΔG_RDS、d-band 等)
  - 若有分类框架：所有类别名及定义

### 4. 对于综述论文

若论文为综述，额外处理：
  - 提取完整的分类框架：所有类别独立列出(类别名 + 定义 + 特征参数 + 代表案例 + 原文献编号)
  - 提取标志性数据列表(用表格，按反应类型分组)
  - 每条编译数据必须标注原文献编号(ref XX, 作者+期刊+年份)
  - 提炼 3-7 条机理通路，每条注明证据来源

## 输出格式

你必须为每篇论文返回一个 YAML-like 结构化结果块。若处理 2 篇论文，用 `---` 分隔
两个块。

每篇的结果块格式(严格遵循)：

```yaml
paper_id: "{paper_id}"
title: "完整标题"
evidence_status: "full_text"

source_map:
  - claim_or_data: "具体数据描述"
    source: "Fig. X / Table Y / Section Z.Z"
  - claim_or_data: "具体数据描述"
    source: "Fig. X, Section Y.Y"

module_coverage:
  synthesis: covered | not_applicable | missing
  performance: covered | not_applicable | missing
  spectra: covered | not_applicable | missing
  mechanism: covered | not_applicable | missing
  methods: covered | not_applicable | missing
  literature: covered

schema_candidates:
  synthesis:
    - record_id: "TBD-by-main"
      paper_id: "{paper_id}"
      module: "synthesis"
      category: "..."
      subject: "..."
      metric: "..."
      value: "..."
      unit: "..."
      condition: "..."
      source: "[Author Year, Journal, Fig. X]"
      confidence: "single_source"
      note: "..."
  # ... 其余 5 个模块同格式 ...

wiki_sync_candidates:
  concepts_to_update: ["概念A"]  # 仅限论文侧 wiki/concepts/，不得指向 computer_kb/wiki
  concepts_to_create: []
  paper_stub_needed: false

missing_data_evidence:
  - module: "synthesis"
    statement: "原文经扫描，Section X.X (Methods)，[具体说明为何无此数据]"

risk_flags:
  - none
```

## 格式铁律

1. source_map 每条必须精确对应一个 Fig./Table/Section
2. schema_candidates 每条必须有 source 字段，值包含 Fig./Table/Section 编号
3. record_id 一律填 "TBD-by-main"，不自行分配
4. missing_data_evidence 不写笼统的"原文未说明"，必须注明扫描了哪个 Section
5. value 和 unit 能拆则拆；不能拆时在 note 中说明原因

## 严禁事项

- 禁止写 kb/**、wiki/**、REVIEWER_LOG.md 任何文件
- 禁止生成 receipt
- 禁止分配 record_id（只填 "TBD-by-main"）
- 禁止 invoke reviewer agent
- 禁止写 已阅读文献/ 下的任何文件
- 禁止跳过 SI 处理
- 禁止在 source 中只写 "[Author Year, Journal]" 而不标注 Fig./Table/Section
- 禁止多条数据共用一个笼统 source

## 子领域模块检查点（帮你逐模块提取）

### 电催化(实验) 检查点
- 催化剂: 组分/合成/形貌/负载量/ECSA
- 电解液: 种类/浓度/pH/阳离子
- 测试构型: H-cell/flow cell/MEA/GDE
- 性能: FE/j/过电位/Tafel/稳定性
- 活性位点证据: XAS/SEIRAS/Raman/DEMS/同位素
- 产物定量: GC/HPLC/NMR/IC

### C-N 偶联 检查点
- N源/C源/产物
- C-N 键形成步(偶联中间体对)
- 协同效应、同位素证据(¹⁵N/¹³C)
- 空白对照、副产物谱

### 电氧化 检查点
- 底物、是否替代 OER、热力学优势
- 机理: 直接氧化/*OH 介导/高价金属/晶格氧
- 活性物种: MOOH/高价金属/晶格氧标记

### 界面水微环境 检查点
- 探测手段: SEIRAS/Raman/SFG/AIMD/MLFF-MD
- 结构描述符: H-down/O-down, ice-like/liquid-like 等
- 阳离子效应、EDL(IHP/OHP/Stern)
- H-bond 网络与 PCET 关联

### DFT 计算 检查点
- 软件/泛函+D3/slab/k-points/U值
- 电化学界面处理(CHE/GC-DFT/显式/隐式)
- ΔG/ZPE/熵校正/RDS
- 描述符: d-band/eg/Bader/ICOHP
- NEB/CI-NEB 势垒

### MLFF+MD 检查点
- 架构: DeePMD/NequIP/MACE/Allegro
- 训练集: AIMD来源/规模/主动学习
- 精度: 能量/力 MAE/RMSE
- 尺度: 原子数/模拟时长
- 增强采样: metadynamics/umbrella/SMD
- 物性: RDF/ADF/MSD/扩散系数/H-bond寿命
```

---

## 10. 完成标准

批量导入完成的硬性标准：

1. 所有 N 篇论文在 `kb/literature.md` 中建立了索引行
2. 每篇非综述论文 ≥5/6 模块有 schema_v1 记录
3. `not_applicable` 模块有 `missing_data_evidence` 支撑（注明扫描了哪个 Section）
4. 最终 receipt（最后一批审计后生成）的 tree hash 匹配当前 `kb/**/*.md` + `wiki/**/*.md` 的 tree hash
5. `kb/REVIEWER_LOG.md` 已追加本次批量导入的完整审计记录
6. `wiki/log.md` 已追加操作记录
7. Stop hook 在会话结束时检测到匹配 receipt → 放行

未达到以上标准前，不得声称"批量导入完成"。

---

## 11. 附录：与精读模式的差异对比

| | 精读模式 | 批量导入模式 |
|---|---|---|
| 触发词 | "导出"/"编译笔记" | "批量导入" |
| 执行者 | 主 AI 亲自精读 | 子 agent 并行读取 + 主 AI 调度 |
| 用户可见输出 | 完整 10 板块笔记 + MD + PDF | 每篇一行汇总 + 审计结果 |
| 阅读方式 | 主 AI 按 READING.md 完整流程 | 子 agent 按中间结果模板提取 |
| kb 写入 | 主 AI 写入 6 模块 | 主 AI 分批写入 6 模块 |
| wiki 同步 | 主 AI 执行 | 主 AI 分批执行 |
| 导出笔记 | 生成精读笔记 MD + PDF | 不生成 |
| 审计 | 单次 reviewer + 单个 receipt | 分批 reviewer + 多个 receipt（最后一个为最终） |
| 安全模式 | workflow_integrity | workflow_integrity |
| 数据质量 | 与精读模式完全一致 | 与精读模式完全一致 |

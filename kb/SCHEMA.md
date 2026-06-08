# 电催化知识库 Schema v1

> 适用范围：`kb/*.md` 七个数据模块（含 `qa.md`）。精读笔记和 `wiki/` 概念页保持人读格式，但其中关键数据必须能回溯到本 schema 化 kb 条目。

## 核心原则

- `kb` 是结构化事实层；`wiki` 是展示层；`已阅读文献` 是完整阅读档案。
- 后续新增、补充、迁移的 kb 条目必须使用 `schema_v1` 字段，不再新增旧格式表格。
- 缺失信息不得编造，统一写 `原条目未载明，需回原文核对`。
- 每条记录必须有 `source`，且 `source` 必须包含论文标识和 Fig./Table/Section/Methods/SI 等出处。
- 若旧条目迁移时无法拆出 `value` 和 `unit`，保留 `metric` 与 `note`，并将 `value`/`unit` 标为待核对。
- Reviewer 只读审计；审计日志由主 AI 写入 `kb/REVIEWER_LOG.md`。

## 通用字段

所有模块至少包含以下字段：

| 字段 | 必填 | 说明 |
|---|---|---|
| `record_id` | 是 | 稳定条目编号，格式建议：`module-0001` |
| `schema_version` | 是 | 当前固定为 `schema_v1` |
| `paper_id` | 是 | 论文短标识，如 `Shen2026`、`Wang2021_ORR` |
| `module` | 是 | `synthesis` / `performance` / `spectra` / `mechanism` / `methods` / `literature` |
| `category` | 是 | 原模块内主题标题或分类 |
| `subject` | 是 | 催化剂、体系、路径、方法、文献或表征对象 |
| `metric` | 是 | 数据项名称，如 FE、峰位、势垒、合成温度、DFT 泛函 |
| `value` | 是 | 具体数值或描述；无法拆分时写 `原条目未拆分，见 note` |
| `unit` | 是 | 单位；无单位或无法拆分时写 `无` 或 `原条目未载明，需回原文核对` |
| `condition` | 是 | 电解液、电位、测试构型、计算模型、表征条件等 |
| `source` | 是 | `[Author Year, Journal/Section/Fig./Table/SI]` |
| `confidence` | 是 | `single_source` / `multi_source` / `verified` / `conflict` / `migrated_from_legacy` |
| `note` | 是 | 保留原始字段、解释、冲突、缺失项、推测边界 |

## 模块专用建议

### synthesis

优先拆分：

| 字段 | 含义 |
|---|---|
| `subject` | 催化剂或材料 |
| `metric` | 前驱体、用量、温度、时间、气氛、洗涤、热处理、负载量 |
| `condition` | 合成路线、水热/电沉积/热解/浸渍等 |

### performance

优先拆分：

| 字段 | 含义 |
|---|---|
| `subject` | 催化剂 + 反应 |
| `metric` | FE、current density、yield、rate、Tafel、TOF、stability、selectivity |
| `value` | 数值 |
| `unit` | `%`、`mA cm^-2`、`mmol h^-1 gcat^-1`、`h` 等 |
| `condition` | 电位、电解液、电池构型、底物浓度 |

### spectra

优先拆分：

| 字段 | 含义 |
|---|---|
| `subject` | 材料/体系/中间体 |
| `metric` | 技术 + 峰/信号，如 Raman peak、XPS BE、m/z、EXAFS CN |
| `value` | 峰位、结合能、m/z、键长、配位数 |
| `unit` | `cm^-1`、`eV`、`m/z`、`Å`、`无` |
| `condition` | 原位条件、电位、光照、反应物 |

### mechanism

优先拆分：

| 字段 | 含义 |
|---|---|
| `subject` | 反应路径、活性位、描述符、中间体 |
| `metric` | RDS、barrier、ΔG、adsorption mode、descriptor、evidence |
| `value` | 数值或路径描述 |
| `unit` | `eV`、`Å`、`无` |
| `condition` | 模型、表面、电解质、反应条件 |

### methods

优先拆分：

| 字段 | 含义 |
|---|---|
| `subject` | 方法、构型、计算设置、表征方案 |
| `metric` | cell type、reference electrode、functional、k-points、slab、probe、reactor |
| `value` | 参数值 |
| `unit` | 物理单位或 `无` |
| `condition` | 适用体系或用途 |

### literature

优先拆分：

| 字段 | 含义 |
|---|---|
| `subject` | 论文、分类框架、种子文献 |
| `metric` | 核心贡献、子领域、类型、关键数字、精读状态 |
| `value` | 结构化描述 |
| `unit` | `无` |
| `condition` | 研究方向或反应体系 |

## 审计要求

Reviewer 对 schema 化 kb 至少检查：

1. 必填字段是否齐全。
2. `source` 是否逐行存在，且不是笼统段落来源。
3. `value` 和 `unit` 是否能拆则拆；不能拆时是否在 `note` 说明。
4. `confidence=migrated_from_legacy` 的条目是否保留原始信息且未编造缺失字段。
5. `wiki` 中关键数字是否能追溯到 schema 化 kb 条目。
6. 后续新增条目不得使用旧格式表格。

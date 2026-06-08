# Paper Reader Workflow · 论文精读工作流

面向电催化与计算电化学研究的 AI 辅助论文精读与知识管理框架。

基于 AI 编码助手（Claude Code / Codex）构建，提供结构化工作流：

- **深度精读**：10 板块分析，覆盖研究问题、体系设计、方法详解、关键结果、机理图景、创新点、局限性、可迁移知识、术语表、追问建议
- **批量入库**：多代理并行处理，论文批量导入结构化知识库
- **知识库**：Schema 校验存储，自动出处追踪（精确到 Fig./Table/Section）
- **Wiki 展示层**：Obsidian 兼容的概念页，从 KB 数据派生，全程可追溯
- **审计门禁**：加密树哈希收据 + 独立审查员，自动质量管控
- **论文抓取**：多源学术搜索工具（Google Scholar、Web of Science、Scopus、知网）

## 适用人群

电催化、C-N 偶联、电氧化、界面水微环境、DFT、MLFF+MD 方向的研究生和博士后。框架假定使用者具备领域知识，聚焦于系统化阅读质量。

## 前置要求

- [Claude Code](https://claude.ai/code) 或 [Codex](https://codex.ai)（或任何能读取 `CLAUDE.md` / `AGENTS.md` 作为项目指令的 AI 编码助手）
- Windows（原生支持），macOS/Linux（审计门禁脚本需安装 PowerShell Core）
- `pdftotext`（批量文本提取用；若 AI 有原生 PDF 支持则非必需）

## 快速开始

```bash
git clone https://github.com/feihanyu953-web/paper-reader-workflow.git
cd paper-reader-workflow
```

然后用 Claude Code 或 Codex 打开此目录。AI 会自动读取 `CLAUDE.md` 并理解所有工作流。

### 首次使用

1. **精读论文**：将 PDF 放入项目文件夹，说"精读这篇论文"
2. **入库**：精读完成后，说"入库这篇论文"
3. **导出笔记**：说"导出笔记"，生成 Markdown + PDF

### 自定义研究领域

编辑 `CLAUDE.md` 第 5 行的研究方向描述。路由规则、KB schema 和审查协议与具体研究领域无关。

## 搭配 computer-kb-workflow 使用

如需计算软件知识管理（DFT/MD/MLFF 参数、报错排查、workflow 设计），安装配套仓库：

```bash
git clone https://github.com/feihanyu953-web/computer-kb-workflow.git
cp -r computer-kb-workflow/computer_kb/ ./computer_kb/
```

然后合并 `.claude/settings.json` 中的 hook 注册，恢复完整路由表。详见 `SETUP.md`。

## 目录结构

```
├── CLAUDE.md              # 项目指令 + 路由规则（Claude Code 入口）
├── AGENTS.md              # Codex 入口适配器
├── md2pdf.ps1             # PDF 导出脚本
├── pdf_style.css           # PDF 样式
├── docs/paper-reader/     # 工作流协议
│   ├── READING.md          #   10 板块精读协议
│   ├── BATCH.md            #   批量入库调度协议
│   ├── EXPORT.md           #   笔记导出协议
│   ├── GATES.md            #   审计门禁机制
│   ├── WIKI_SYNC.md        #   KB→Wiki 同步规则
│   └── ORIGIN_XRD.md       #   XRD 图表自动化
├── kb/                    # 论文知识库（仅框架）
│   ├── INDEX.md            #   路由索引 + 模块摘要
│   ├── SCHEMA.md           #   Schema v1 字段契约
│   ├── REVIEWER.md         #   审查协议
│   └── reference/          #   公开参考数据（Raman/IR/XPS）
├── wiki/                  # Wiki 展示层（骨架）
├── paper-fetcher/         # 多源学术搜索工具
└── .claude/               # Claude Code 集成
    ├── settings.json       #   Stop hook 注册
    ├── hooks/              #   审计门禁 PowerShell 脚本
    ├── agents/             #   独立审查员代理
    ├── scripts/            #   收据生成
    ├── skills/             #   通用工作流技能
    └── commands/opsx/      #   OpenSpec 命令
```

## 许可证

MIT

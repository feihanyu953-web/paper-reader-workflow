# Paper Reader Workflow · 论文精读工作流

面向任意研究方向的 AI 辅助论文精读与知识管理框架。内置电催化示例，一句命令即可适配到你的领域。

基于 AI 编码助手（Claude Code / Codex）构建，提供结构化工作流：

- **深度精读**：10 板块分析，覆盖研究问题、体系设计、方法详解、关键结果、机理图景、创新点、局限性、可迁移知识、术语表、追问建议
- **批量入库**：多代理并行处理，论文批量导入结构化知识库
- **知识库**：Schema 校验存储，自动出处追踪（精确到 Fig./Table/Section）
- **Wiki 展示层**：Obsidian 兼容的概念页，从 KB 数据派生，全程可追溯
- **审计门禁**：加密树哈希收据 + 独立审查员，自动质量管控
- **论文抓取**：多源学术搜索工具（Google Scholar、Web of Science、Scopus、知网）

## 领域无关 · 一句命令配置

框架内置**电催化作为示例**，但适用于**任何研究领域**——锂电、光催化、有机合成、生物医学、材料科学等。

克隆后用 Claude Code 或 Codex 打开，说：

> "我是做锂离子电池固态电解质方向的"

AI 自动读取 `CONFIGURE.md`，找到所有领域标记（`<!-- DOMAIN:XXX -->`），将子领域、性能指标、表征手段、深挖模块、参考数据全部替换为你的领域术语。

**零手动修改。3 秒完成。**

详见 `CONFIGURE.md`。

## 安装

### 方案 A：Claude Code（推荐，完整功能支持）

Claude Code 是 Anthropic 官方 CLI 和 IDE 扩展，原生支持 `CLAUDE.md` 项目指令、hooks、agents 和 skills，可获得完整审计门禁系统和全部 22 个工作流技能。

**VS Code / Cursor / Windsurf：**

1. 在 VS Code 扩展市场安装 [Claude Code 扩展](https://marketplace.visualstudio.com/items?itemName=anthropic.claude-code)
2. 打开命令面板（`Ctrl+Shift+P`）→ `Claude Code: Open Claude Code`

**终端（CLI）：**

```bash
# npm 安装（需 Node.js ≥ 18）
npm install -g @anthropic-ai/claude-code

# 或 winget 安装（Windows）
winget install Anthropic.ClaudeCode

# 启动
claude
```

**JetBrains（IntelliJ / PyCharm / WebStorm）：**

在 JetBrains 插件市场安装 [Claude Code 插件](https://plugins.jetbrains.com/plugin/26538-claude-code)。

> Claude Code 需要 [Anthropic API Key](https://console.anthropic.com/) 或 Claude 订阅。

### 方案 B：Codex（备选）

Codex 是 OpenAI 出品的 AI 编码助手，读取 `AGENTS.md` 作为项目指令，原生 PDF 视觉识别对论文阅读非常友好。

**安装：**

```bash
# npm 安装（需 Node.js ≥ 18）
npm install -g @openai/codex

# 启动
codex
```

> **注意：** Codex 支持核心工作流（精读、批量入库、KB 管理），但没有 hook 系统，审计门禁需手动执行，详见 `SETUP.md`。

### 方案 C：其他 AI 编码助手

任何能读取 `CLAUDE.md` / `AGENTS.md` 作为项目指令的助手均可使用。核心框架（路由规则、KB schema、审查协议）为纯 Markdown，平台无关。

### 其他工具

| 工具 | 是否必需 | 安装方式 |
|---|---|---|
| Git | 必需 | `winget install Git.Git` 或 [git-scm.com](https://git-scm.com) |
| `pdftotext` | 可选 | `winget install poppler` 或 `sudo apt install poppler-utils` |
| PowerShell Core | 仅 macOS/Linux | `brew install powershell` 或 `sudo apt install powershell` |

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

### 一句话配置研究领域

无需手动编辑。说"我是做 XXX 方向的"，AI 自动替换路由示例、子领域模块和参考数据。详见上方「领域无关」说明。

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

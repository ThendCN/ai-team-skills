# AI Team Skills for Claude Code

中文 | [English](README_EN.md)

将 Antigravity CLI（Gemini）和 Codex CLI 集成为 Claude Code 的 skill，让 Claude Code 能够：

- 委派 UI 设计任务给 **Gemini**（gemini-agent，通过 Antigravity CLI `agy` 调用，默认 `gemini-3.8-flash-high`）
- 委派代码编写/审查任务给 **Codex**（codex-agent，默认 `gpt-6.1-sol`，推理强度 high）
- 用 **Codex 内置图片生成**做配图、图标、插画（image-worker）
- 编排多 Agent 协作流水线（ai-team），带交叉审查门禁和 worktree 并行隔离

## 架构

```
Claude Code (编排者/大脑)
    ├── ai-team skill       → 多 Agent 流水线编排
    ├── gemini-agent skill  → agy (Antigravity CLI) → UI/前端设计
    ├── codex-agent skill   → codex-cli  → 代码编写/审查
    └── agents/             → Worker Agent 定义（ai-team 流水线所需）
        ├── codex-worker.md → Codex Worker subagent
        ├── gemini-worker.md → Gemini Worker subagent
        └── image-worker.md → 配图 Worker subagent（Codex 内置图片生成）
```

## Skills

### ai-team

多 Agent 协作流水线，自动编排 Claude (Lead) + Codex (代码) + Gemini (UI) + 配图 Worker。

- **交叉审查门禁**：Codex 写的代码由 Gemini 审查，Gemini 写的 UI 由 Codex 审查；不通过就打回，默认最多 2 轮
- **续聊修改**：打回时 worker 用 `--resume <SESSION_ID>` 接着原会话改，不从头重来
- **worktree 隔离**：多个 worker 并行修改同一仓库时，各用一个 git worktree，最后由 Lead 合并
- **配图**：image-worker 用 Codex 内置图片生成能力出图，保存到项目里

```
/ai-team <复杂任务描述>
```

适用于全栈开发、大型重构、UI→实现联动等需要多 agent 协作的场景。

- 流水线模板：`ai-team/references/pipeline-templates.md`

### gemini-agent

Gemini AI 代理 - UI 设计与前端开发专家。通过 Antigravity CLI `agy` 调用（gemini CLI 已不再支持个人账号登录）。

```
/gemini-agent <UI 设计描述>
```

- 包装脚本：`gemini-agent/scripts/gemini-run.sh`（Linux/macOS）、`gemini-agent/scripts/gemini-run.ps1`（Windows）
- Prompt 模板：`gemini-agent/references/prompt-templates.md`
- 支持 plan 只读模式：`-m plan`，用于交叉审查
- 支持续聊：`--resume <SESSION_ID>`

### codex-agent

Codex AI 代理 - 代码编写与实现专家。支持 exec（编写）和 review（审查）两种模式。

```
/codex-agent <代码任务描述>
```

- 包装脚本：`codex-agent/scripts/codex-run.sh`（Linux/macOS）、`codex-agent/scripts/codex-run.ps1`（Windows）
- Prompt 模板：`codex-agent/references/prompt-templates.md`
- 支持 review 模式：`-r --uncommitted` 审查未提交变更
- 支持续聊：`--resume <SESSION_ID>`
- 支持并行任务拆分，提升长时间任务效率

## 协作模式

### 单 Agent 委派

Claude Code 分析任务 → 构建 prompt → 调用对应 CLI → 收集结果（stderr 里带 `SESSION_ID`，可续聊修改）

### 多 Agent 流水线（ai-team）

```
模式 A: UI → 实现（串行）
  gemini-worker 设计 UI → codex-worker 审查 ⇄ 修复 → codex-worker 实现 → gemini-worker 审查 ⇄ 修复 → 测试

模式 B: 审查 → 修复（串行）
  codex-worker 审查 → Claude 确认 → codex-worker 修复 → gemini-worker 复审 ⇄ 修复 → 测试

模式 C: 多模块并行（每个 worker 一个 worktree）
  codex-worker-1 模块 A ⇄ 交叉审查 ─┐
  codex-worker-2 模块 B ⇄ 交叉审查 ─┤→ Claude 合并 → 集成测试
  gemini-worker UI      ⇄ 交叉审查 ─┘

配图（可插入任意模式）
  image-worker 生成素材 → Claude 查看 ⇄ 续聊修改 → UI worker 引用
```

## 前置要求

- [Antigravity CLI](https://antigravity.google)（`agy`）已安装并登录
- [Codex CLI](https://github.com/openai/codex) 0.159 及以上已安装并配置（默认模型 `gpt-6.1-sol` 需要新版才能识别；配图需要 `image_generation` 功能开启，新版默认开启，可用 `codex features list` 查看）
- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) 已安装
- Linux / macOS 需要 `python3`（解析 agy 的 JSON 输出）

## 安装

将 skill 目录和 agent 定义复制到你的 Claude Code 目录：

```bash
# Linux / macOS - 全部安装
cp -r ai-team gemini-agent codex-agent ~/.claude/skills/
mkdir -p ~/.claude/agents && cp agents/*.md ~/.claude/agents/

# Linux / macOS - 只安装单 agent（不需要流水线编排）
cp -r gemini-agent codex-agent ~/.claude/skills/
```

```powershell
# Windows (PowerShell) - 全部安装
@("ai-team", "gemini-agent", "codex-agent") | ForEach-Object { Copy-Item -Recurse $_ "$env:USERPROFILE\.claude\skills\" }
New-Item -ItemType Directory -Force "$env:USERPROFILE\.claude\agents" | Out-Null
Copy-Item agents\*.md "$env:USERPROFILE\.claude\agents\"

# Windows (PowerShell) - 只安装单 agent
@("gemini-agent", "codex-agent") | ForEach-Object { Copy-Item -Recurse $_ "$env:USERPROFILE\.claude\skills\" }
```

> **重要**：使用 ai-team 流水线模式时，必须安装 `agents/` 目录下的 Worker Agent 定义文件到 `~/.claude/agents/`。
> 这些文件定义了 `codex-worker`、`gemini-worker`、`image-worker` 三个自定义 subagent，是 Team 模式正常运行的前提。

> **Windows**：`.ps1` 脚本已同步新功能（续聊、plan 模式、agy），但维护者没有 Windows 环境，尚未实测，欢迎反馈。

## License

MIT

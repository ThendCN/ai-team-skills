# AI Team Skills for Claude Code

将 Gemini CLI 和 Codex CLI 集成为 Claude Code 的 skill，让 Claude Code 能够：

- 委派 UI 设计任务给 **Gemini gemini-3-pro-preview**（gemini-agent）
- 委派代码编写/审查任务给 **Codex gpt-5.3-codex**（codex-agent）
- 编排多 Agent 协作流水线（ai-team）

## 架构

```
Claude Code (编排者/大脑)
    ├── ai-team skill       → 多 Agent 流水线编排
    ├── gemini-agent skill  → gemini-cli → UI/前端设计
    └── codex-agent skill   → codex-cli  → 代码编写/审查
```

## Skills

### ai-team

多 Agent 协作流水线，自动编排 Claude (Lead) + Codex (代码) + Gemini (UI)。

```
/ai-team <复杂任务描述>
```

适用于全栈开发、大型重构、UI→实现联动等需要多 agent 协作的场景。

- 流水线模板：`ai-team/references/pipeline-templates.md`

### gemini-agent

Gemini (gemini-3-pro-preview) AI 代理 - UI 设计与前端开发专家。

```
/gemini-agent <UI 设计描述>
```

- 包装脚本：`gemini-agent/scripts/gemini-run.sh`（Linux/macOS）、`gemini-agent/scripts/gemini-run.ps1`（Windows）
- Prompt 模板：`gemini-agent/references/prompt-templates.md`

### codex-agent

Codex (gpt-5.3-codex, reasoning: high) AI 代理 - 代码编写与实现专家。支持 exec（编写）和 review（审查）两种模式。

```
/codex-agent <代码任务描述>
```

- 包装脚本：`codex-agent/scripts/codex-run.sh`（Linux/macOS）、`codex-agent/scripts/codex-run.ps1`（Windows）
- Prompt 模板：`codex-agent/references/prompt-templates.md`
- 支持 review 模式：`-r --uncommitted` 审查未提交变更
- 支持并行任务拆分，提升长时间任务效率

## 协作模式

### 单 Agent 委派

Claude Code 分析任务 → 构建 prompt → 调用对应 CLI → 收集结果

### 多 Agent 流水线（ai-team）

```
模式 A: UI → 实现（串行）
  gemini-worker 设计 UI → Claude 审查 → codex-worker 实现 → 测试

模式 B: 审查 → 修复（串行）
  codex-worker 审查 → Claude 确认 → codex-worker 修复 → 测试

模式 C: 多模块并行
  codex-worker-1 模块 A ─┐
  codex-worker-2 模块 B ─┤→ Claude 整合 → 集成测试
  gemini-worker UI      ─┘
```

## 前置要求

- [Gemini CLI](https://github.com/google-gemini/gemini-cli) 已安装并登录
- [Codex CLI](https://github.com/openai/codex) 已安装并配置
- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) 已安装

## 安装

将 skill 目录复制到你的 Claude Code skills 目录：

```bash
# Linux / macOS - 全部安装
cp -r ai-team gemini-agent codex-agent ~/.claude/skills/

# Linux / macOS - 只安装单 agent（不需要流水线编排）
cp -r gemini-agent codex-agent ~/.claude/skills/
```

```powershell
# Windows (PowerShell) - 全部安装
@("ai-team", "gemini-agent", "codex-agent") | ForEach-Object { Copy-Item -Recurse $_ "$env:USERPROFILE\.claude\skills\" }

# Windows (PowerShell) - 只安装单 agent
@("gemini-agent", "codex-agent") | ForEach-Object { Copy-Item -Recurse $_ "$env:USERPROFILE\.claude\skills\" }
```

> Windows 用户说明：包装脚本同时提供 `.sh`（Bash）和 `.ps1`（PowerShell）两个版本。
> Claude Code 在 Windows 上会自动使用 `.ps1` 脚本（需要 PowerShell 5.1+ 或 pwsh）。

## License

MIT

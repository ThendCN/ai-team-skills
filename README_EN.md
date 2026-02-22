# AI Team Skills for Claude Code

[中文](README.md) | English

Integrate Gemini CLI and Codex CLI as Claude Code skills, enabling Claude Code to:

- Delegate UI design tasks to **Gemini gemini-3-pro-preview** (gemini-agent)
- Delegate code writing/review tasks to **Codex gpt-5.3-codex** (codex-agent)
- Orchestrate multi-agent collaboration pipelines (ai-team)

## Architecture

```
Claude Code (Orchestrator)
    ├── ai-team skill       → Multi-agent pipeline orchestration
    ├── gemini-agent skill  → gemini-cli → UI/Frontend design
    ├── codex-agent skill   → codex-cli  → Code writing/review
    └── agents/             → Worker Agent definitions (required for ai-team)
        ├── codex-worker.md → Codex Worker subagent
        └── gemini-worker.md → Gemini Worker subagent
```

## Skills

### ai-team

Multi-agent collaboration pipeline that orchestrates Claude (Lead) + Codex (Code) + Gemini (UI).

```
/ai-team <complex task description>
```

Ideal for full-stack development, large-scale refactoring, and UI→implementation workflows.

- Pipeline templates: `ai-team/references/pipeline-templates.md`

### gemini-agent

Gemini (gemini-3-pro-preview) AI agent — UI design and frontend development expert.

```
/gemini-agent <UI design description>
```

- Wrapper scripts: `gemini-agent/scripts/gemini-run.sh` (Linux/macOS), `gemini-agent/scripts/gemini-run.ps1` (Windows)
- Prompt templates: `gemini-agent/references/prompt-templates.md`

### codex-agent

Codex (gpt-5.3-codex, reasoning: high) AI agent — code writing and implementation expert. Supports exec (write) and review (audit) modes.

```
/codex-agent <code task description>
```

- Wrapper scripts: `codex-agent/scripts/codex-run.sh` (Linux/macOS), `codex-agent/scripts/codex-run.ps1` (Windows)
- Prompt templates: `codex-agent/references/prompt-templates.md`
- Review mode: `-r --uncommitted` to review uncommitted changes
- Parallel task splitting for long-running tasks

## Collaboration Modes

### Single Agent Delegation

Claude Code analyzes task → builds prompt → calls corresponding CLI → collects results

### Multi-Agent Pipeline (ai-team)

```
Mode A: UI → Implementation (sequential)
  Gemini designs UI → Claude reviews → Codex implements → Tests

Mode B: Review → Fix (sequential)
  Codex reviews code → Claude confirms → Codex fixes issues → Tests

Mode C: Multi-module parallel
  Codex worker 1: Module A ─┐
  Codex worker 2: Module B ─┤→ Claude integrates → Integration tests
  Gemini worker:  UI        ─┘
```

## Prerequisites

- [Gemini CLI](https://github.com/google-gemini/gemini-cli) installed and authenticated
- [Codex CLI](https://github.com/openai/codex) installed and configured
- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) installed

## Installation

Copy the skill directories and agent definitions to your Claude Code directory:

```bash
# Linux / macOS - Install all
cp -r ai-team gemini-agent codex-agent ~/.claude/skills/
mkdir -p ~/.claude/agents && cp agents/*.md ~/.claude/agents/

# Linux / macOS - Single agent only (no pipeline orchestration)
cp -r gemini-agent codex-agent ~/.claude/skills/
```

```powershell
# Windows (PowerShell) - Install all
@("ai-team", "gemini-agent", "codex-agent") | ForEach-Object { Copy-Item -Recurse $_ "$env:USERPROFILE\.claude\skills\" }
New-Item -ItemType Directory -Force "$env:USERPROFILE\.claude\agents" | Out-Null
Copy-Item agents\*.md "$env:USERPROFILE\.claude\agents\"

# Windows (PowerShell) - Single agent only
@("gemini-agent", "codex-agent") | ForEach-Object { Copy-Item -Recurse $_ "$env:USERPROFILE\.claude\skills\" }
```

> **Important**: To use the ai-team pipeline mode, you must install the Worker Agent definition files from `agents/` to `~/.claude/agents/`.
> These files define the `codex-worker` and `gemini-worker` custom subagents required for Team mode to function.

## License

MIT

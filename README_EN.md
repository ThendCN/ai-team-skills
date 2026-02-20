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
    └── codex-agent skill   → codex-cli  → Code writing/review
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

Copy the skill directories to your Claude Code skills directory:

```bash
# Linux / macOS - Install all
cp -r ai-team gemini-agent codex-agent ~/.claude/skills/

# Linux / macOS - Single agent only (no pipeline orchestration)
cp -r gemini-agent codex-agent ~/.claude/skills/
```

```powershell
# Windows (PowerShell) - Install all
@("ai-team", "gemini-agent", "codex-agent") | ForEach-Object { Copy-Item -Recurse $_ "$env:USERPROFILE\.claude\skills\" }

# Windows (PowerShell) - Single agent only
@("gemini-agent", "codex-agent") | ForEach-Object { Copy-Item -Recurse $_ "$env:USERPROFILE\.claude\skills\" }
```

> Windows users: Wrapper scripts are provided in both `.sh` (Bash) and `.ps1` (PowerShell) versions.
> Claude Code on Windows will automatically use `.ps1` scripts (requires PowerShell 5.1+ or pwsh).

## License

MIT

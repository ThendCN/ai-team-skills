# AI Team Skills for Claude Code

[中文](README.md) | English

Integrate Antigravity CLI (Gemini) and Codex CLI as Claude Code skills, enabling Claude Code to:

- Delegate UI design tasks to **Gemini** (gemini-agent, via Antigravity CLI `agy`, defaults to `gemini-3.8-flash-high`)
- Delegate code writing/review tasks to **Codex** (codex-agent, defaults to `gpt-6.1-sol` with high reasoning effort)
- Generate illustrations, icons and artwork with **Codex built-in image generation** (image-worker)
- Orchestrate multi-agent collaboration pipelines (ai-team) with cross-review gates and worktree isolation

## Architecture

```
Claude Code (Orchestrator)
    ├── ai-team skill       → Multi-agent pipeline orchestration
    ├── gemini-agent skill  → agy (Antigravity CLI) → UI/Frontend design
    ├── codex-agent skill   → codex-cli  → Code writing/review
    └── agents/             → Worker Agent definitions (required for ai-team)
        ├── codex-worker.md → Codex Worker subagent
        ├── gemini-worker.md → Gemini Worker subagent
        └── image-worker.md → Image Worker subagent (Codex built-in image generation)
```

## Skills

### ai-team

Multi-agent collaboration pipeline that orchestrates Claude (Lead) + Codex (Code) + Gemini (UI) + Image Worker.

- **Cross-review gate**: Codex code is reviewed by Gemini, Gemini UI is reviewed by Codex; failures are sent back for fixes, up to 2 rounds by default
- **Resume to fix**: rejected work is fixed by resuming the original session with `--resume <SESSION_ID>` instead of starting over
- **Worktree isolation**: parallel workers editing the same repo each get their own git worktree; the Lead merges at the end
- **Images**: image-worker generates assets with Codex built-in image generation and saves them into the project

```
/ai-team <complex task description>
```

Ideal for full-stack development, large-scale refactoring, and UI→implementation workflows.

- Pipeline templates: `ai-team/references/pipeline-templates.md`

### gemini-agent

Gemini AI agent — UI design and frontend development expert. Runs through Antigravity CLI `agy` (gemini CLI no longer supports personal account sign-in).

```
/gemini-agent <UI design description>
```

- Wrapper scripts: `gemini-agent/scripts/gemini-run.sh` (Linux/macOS), `gemini-agent/scripts/gemini-run.ps1` (Windows)
- Prompt templates: `gemini-agent/references/prompt-templates.md`
- Plan (read-only) mode: `-m plan`, used for cross-review
- Resume: `--resume <SESSION_ID>`

### codex-agent

Codex AI agent — code writing and implementation expert. Supports exec (write) and review (audit) modes.

```
/codex-agent <code task description>
```

- Wrapper scripts: `codex-agent/scripts/codex-run.sh` (Linux/macOS), `codex-agent/scripts/codex-run.ps1` (Windows)
- Prompt templates: `codex-agent/references/prompt-templates.md`
- Review mode: `-r --uncommitted` to review uncommitted changes
- Resume: `--resume <SESSION_ID>`
- Parallel task splitting for long-running tasks

## Collaboration Modes

### Single Agent Delegation

Claude Code analyzes task → builds prompt → calls corresponding CLI → collects results (stderr includes `SESSION_ID` for follow-up fixes)

### Multi-Agent Pipeline (ai-team)

```
Mode A: UI → Implementation (sequential)
  Gemini designs UI → Codex reviews ⇄ fix → Codex implements → Gemini reviews ⇄ fix → Tests

Mode B: Review → Fix (sequential)
  Codex reviews code → Claude confirms → Codex fixes issues → Gemini re-reviews ⇄ fix → Tests

Mode C: Multi-module parallel (one worktree per worker)
  Codex worker 1: Module A ⇄ cross-review ─┐
  Codex worker 2: Module B ⇄ cross-review ─┤→ Claude merges → Integration tests
  Gemini worker:  UI       ⇄ cross-review ─┘

Images (can be added to any mode)
  Image worker generates assets → Claude inspects ⇄ resume to revise → UI worker uses them
```

## Prerequisites

- [Antigravity CLI](https://antigravity.google) (`agy`) installed and signed in
- [Codex CLI](https://github.com/openai/codex) 0.159+ installed and configured (the default model `gpt-6.1-sol` requires a recent version; images need the `image_generation` feature, enabled by default in recent versions; check with `codex features list`)
- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) installed
- `python3` on Linux / macOS (parses agy JSON output)

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
> These files define the `codex-worker`, `gemini-worker` and `image-worker` custom subagents required for Team mode to function.

> **Windows**: the `.ps1` scripts include the new features (resume, plan mode, agy), but the maintainer has no Windows environment and they are untested. Feedback welcome.

## License

MIT

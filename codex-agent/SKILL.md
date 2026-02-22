---
name: codex-agent
description: "Codex (gpt-5.3-codex high) AI 代理 - 代码编写与实现专家。支持代码编写、功能实现、bug 修复、重构、测试、代码审查。使用 /codex-agent <描述> 或 /codex <描述> 委派代码任务给 Codex。"
---

# Codex Agent - AI 团队代码实现专家

将代码编写和实现任务委派给 Codex (gpt-5.3-codex, reasoning effort: high)，由 Claude Code 编排和审查。

## 用法

```
/codex-agent <代码任务描述>
/codex <代码任务描述>
```

也可由 Claude Code 在分析任务后自动委派（当任务涉及代码编写/实现/修复/重构/测试/审查时）。

## 执行方式

### 方式一：使用包装脚本（推荐）

**Linux / macOS (Bash)**：
```bash
# 标准执行（full-auto 沙箱，安全默认）
bash ~/.claude/skills/codex-agent/scripts/codex-run.sh -f /tmp/codex-prompt.txt -d <工作目录>

# 需要完整权限时（如安装依赖、修改系统文件）
bash ~/.claude/skills/codex-agent/scripts/codex-run.sh -f /tmp/codex-prompt.txt -s dangerous -d <工作目录>

# 只读代码审查
bash ~/.claude/skills/codex-agent/scripts/codex-run.sh -r --uncommitted -d <工作目录> -o /tmp/review.txt

# 将结果写入文件（流水线模式）
bash ~/.claude/skills/codex-agent/scripts/codex-run.sh -f /tmp/codex-prompt.txt -o /tmp/codex-result.txt -d <工作目录>
```

**Windows（重要：必须使用 powershell.exe 调用 .ps1 脚本）**：

> Claude Code 在 Windows 上使用 bash shell，但 .ps1 脚本不能用 bash 执行。
> 必须通过 `powershell.exe -ExecutionPolicy Bypass -File` 调用。
> 不要使用 `pwsh`（除非确认已安装 PowerShell 7）。
> 不要使用 `-Command "& 'script.ps1'"` 形式（转义问题多）。

```bash
# 标准执行（从 bash 调用 PowerShell 脚本）
powershell.exe -ExecutionPolicy Bypass -File ~/.claude/skills/codex-agent/scripts/codex-run.ps1 -File /tmp/codex-prompt.txt -Dir <工作目录>

# 需要完整权限时
powershell.exe -ExecutionPolicy Bypass -File ~/.claude/skills/codex-agent/scripts/codex-run.ps1 -File /tmp/codex-prompt.txt -Sandbox dangerous -Dir <工作目录>

# 只读代码审查
powershell.exe -ExecutionPolicy Bypass -File ~/.claude/skills/codex-agent/scripts/codex-run.ps1 -Review -Uncommitted -Dir <工作目录> -Output /tmp/review.txt
```

**Windows 注意事项**：
- Prompt 文件必须是 UTF-8 编码（无 BOM），脚本内部已处理 BOM 问题
- 脚本已自动处理 npm/pnpm 安装的 .ps1 包装脚本兼容性问题

### 方式二：直接调用 codex CLI（备选）

当包装脚本出问题时，可直接调用：

```bash
# 确保 PATH 包含 pnpm 全局 bin
export PATH="$HOME/.local/share/pnpm:$PATH"

# 代码编写/修复（通过 stdin 传递 prompt）
codex exec -s danger-full-access -C <工作目录> -o /tmp/result.txt - < /tmp/prompt.txt

# 代码审查（review 子命令）
codex exec review --uncommitted > /tmp/review.txt 2>&1
```

### 脚本参数

```
codex-run.sh / codex-run.ps1 [OPTIONS] [prompt...]

Bash:                                PowerShell:
  -m, --model <model>                  -Model <model>
  -d, --dir <directory>                -Dir <directory>
  -t, --timeout <seconds>              -Timeout <seconds>  (默认 900s)
  -s, --sandbox <mode>                 -Sandbox <mode>     (默认 full-auto)
  -o, --output <file>                  -Output <file>
  -f, --file <file>                    -File <file>
  -r, --review                         -Review
      --uncommitted                    -Uncommitted
      --base <branch>                  -Base <branch>
```

**默认值**：
- 超时时间：900s (15分钟)，适合 codex 任务的典型执行时间
- 沙箱模式：full-auto（安全默认），实际项目通常需要 dangerous 模式
- 脚本默认跳过 git 仓库检查（`--skip-git-repo-check`），可在任何目录中使用

## Codex CLI 关键参数映射（重要）

以下是 codex CLI 的**正确参数**，脚本已处理映射：

| 功能 | 正确参数 | 错误参数（不要用） |
|------|----------|---------------------|
| 只读沙箱 | `-s read-only` | `--read-only` |
| 完整权限 | `--dangerously-bypass-approvals-and-sandbox` | `--dangerously-auto-approve` |
| 自动沙箱 | `--full-auto` | - |
| 工作目录 | `-C <dir>` | `--workdir` |
| 输出文件 | `-o <file>`（仅 exec 模式） | review 模式不支持 -o |
| stdin prompt | `- < file.txt`（末尾加 `-`） | `-f file.txt`（不存在此参数） |

## 沙箱模式说明

| 模式 | codex 参数 | 适用场景 | 推荐度 |
|------|-----------|----------|--------|
| `full-auto` | `--full-auto` | 简单的代码编写任务（不需要安装依赖） | 默认 |
| `dangerous` | `--dangerously-bypass-approvals-and-sandbox` | **实际项目开发**：需要安装依赖、运行测试、修改配置 | ⭐ 常用 |
| `read-only` | `-s read-only` | 代码审查、分析（不修改文件） | 审查专用 |

**实际使用建议**：
- 大多数实际项目任务需要使用 `dangerous` 模式
- `full-auto` 模式限制较多，适合简单场景
- 使用 `-s dangerous` 参数指定沙箱模式

## 两种模式

### exec 模式（默认）- 代码编写/修复

用于代码编写、功能实现、bug 修复、重构等需要修改文件的任务。

**常用命令**：
```bash
# Linux/macOS - 实际项目开发（推荐）
bash ~/.claude/skills/codex-agent/scripts/codex-run.sh \
  -f {workdir}/.tmp/prompt.txt \
  -s dangerous \
  -o {workdir}/.tmp/output.txt \
  -d {workdir}

# Windows - 实际项目开发（推荐）
powershell.exe -ExecutionPolicy Bypass -File ~/.claude/skills/codex-agent/scripts/codex-run.ps1 \
  -File {workdir}/.tmp/prompt.txt \
  -Sandbox dangerous \
  -Output {workdir}/.tmp/output.txt \
  -Dir {workdir}
```

**参数说明**：
- `-s dangerous` / `-Sandbox dangerous`：允许安装依赖、运行测试（实际项目必需）
- `-o` / `-Output`：将结果写入文件，便于后续处理
- `-f` / `-File`：从文件读取 prompt，避免 shell 转义问题

### review 模式 - 代码审查

用于代码审查、安全检查、质量分析等只读任务。

**常用命令**：
```bash
# Linux/macOS - 审查未提交的变更
bash ~/.claude/skills/codex-agent/scripts/codex-run.sh \
  -r --uncommitted \
  -o {workdir}/.tmp/review.txt \
  -d {workdir}

# Windows - 审查未提交的变更
powershell.exe -ExecutionPolicy Bypass -File ~/.claude/skills/codex-agent/scripts/codex-run.ps1 \
  -Review -Uncommitted \
  -Output {workdir}/.tmp/review.txt \
  -Dir {workdir}
```

**参数说明**：
- `-r` / `-Review`：启用 review 模式
- `--uncommitted` / `-Uncommitted`：审查未提交的变更
- `--base <branch>` / `-Base <branch>`：审查相对于指定分支的变更

**review 模式注意事项**：
- `codex exec review` 不支持 `-C`（工作目录）参数，需要先 `cd`
- `codex exec review` 不支持 `-o`（输出文件）参数，需要用重定向
- review 输出在 stderr，捕获时需要 `2>&1`
- `--uncommitted` 和自定义 prompt 不能同时使用

## Prompt 构建指南

将用户需求转化为 Codex 友好的 prompt 时：

1. **明确任务** - 清晰描述要实现的功能或修复的问题
2. **提供上下文** - 相关文件路径、现有代码结构、依赖关系
3. **技术约束** - 语言版本、框架要求、编码规范
4. **验收标准** - 期望的输出、测试要求
5. **文件操作** - 明确指出要创建/修改的文件路径

参考 `references/prompt-templates.md` 获取完整模板。

## 输出捕获

exec 模式使用 `-o` 参数，review 模式使用重定向：

```bash
# exec 模式
bash ~/.claude/skills/codex-agent/scripts/codex-run.sh \
  -f /tmp/codex-prompt.txt \
  -o /tmp/codex-result.txt \
  -d ./project

# review 模式
bash ~/.claude/skills/codex-agent/scripts/codex-run.sh \
  -r --uncommitted \
  -o /tmp/codex-review.txt \
  -d ./project
```

Claude 随后读取输出文件获取执行结果。

## 常见问题排查

| 问题 | 原因 | 解决方案 |
|------|------|----------|
| `command not found: codex` | PATH 未包含 pnpm 全局 bin | 脚本已自动处理；直接调用时需 `export PATH="$HOME/.local/share/pnpm:$PATH"` |
| `unexpected argument '--read-only'` | 使用了错误的沙箱参数 | 正确参数是 `-s read-only` |
| `unexpected argument '-f'` | codex exec 不支持 -f | 使用 stdin：`codex exec ... - < file.txt` |
| review 输出为空 | review 输出在 stderr | 使用 `2>&1` 重定向 |
| `cannot be used with '[PROMPT]'` | review --uncommitted 和 prompt 冲突 | 二选一：用 --uncommitted 或自定义 prompt |
| Windows PS1 脚本启动 codex 失败 | npm/pnpm 安装的 codex 是 .ps1 包装脚本，Process.Start() 无法直接执行 | 脚本已自动处理：优先使用 .cmd 版本，否则通过 powershell.exe 间接执行 |

**注意**：包装脚本默认跳过 git 仓库检查，可在任何目录中使用。如果需要 git 相关功能（如 `--uncommitted`），请确保工作目录是 git 仓库。

## 任务路由

当用户请求包含以下关键词时，应路由到 codex-agent：
- 实现、编写、修复、重构、测试、代码、功能、API、后端、数据库、bug
- review、审查、检查代码、代码质量

**注意**：如果任务涉及多个独立模块或需要 UI + 后端协作，考虑使用 `/ai-team` 进行多 Agent 并行协作。

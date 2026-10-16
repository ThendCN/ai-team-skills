---
name: codex-agent
description: "Codex AI 代理 - 代码编写与实现专家。支持代码编写、功能实现、bug 修复、重构、测试、代码审查。使用 /codex-agent <描述> 或 /codex <描述> 委派代码任务给 Codex。"
---

# Codex Agent - AI 团队代码实现专家

将代码编写和实现任务委派给 Codex（模型和推理强度使用 `~/.codex/config.toml` 中的配置），由 Claude Code 编排和审查。

## 用法

```
/codex-agent <代码任务描述>
/codex <代码任务描述>
```

也可由 Claude Code 在分析任务后自动委派（当任务涉及代码编写/实现/修复/重构/测试/审查时）。

## 执行步骤

1. **判断当前平台**：检查运行环境是 Linux/macOS 还是 Windows
   - Linux/macOS → 使用 `codex-run.sh`
   - Windows → 使用 `codex-run.ps1`（必须通过 `powershell.exe -ExecutionPolicy Bypass -File` 调用）
2. **准备 prompt 文件**：将任务描述写入临时文件（推荐使用 `-f` / `-File` 参数，避免 shell 转义问题）
3. **选择沙箱模式**：简单任务用 `workspace-write`（默认），实际项目开发用 `dangerous`
4. **执行脚本**：调用对应平台的包装脚本
5. **读取结果**：通过 `-o` / `-Output` 指定的输出文件获取执行结果
6. **记下 SESSION_ID**：脚本结束时在 stderr 打印 `SESSION_ID: <id>`，需要修改时用 `--resume` / `-Resume` 续聊

## 执行方式

### 方式一：使用包装脚本（推荐）

**Linux / macOS (Bash)**：
```bash
# 标准执行（workspace-write 沙箱，安全默认）
bash ~/.claude/skills/codex-agent/scripts/codex-run.sh -f /tmp/codex-prompt.txt -d <工作目录>

# 需要完整权限时（如安装依赖、修改系统文件）
bash ~/.claude/skills/codex-agent/scripts/codex-run.sh -f /tmp/codex-prompt.txt -s dangerous -d <工作目录>

# 只读代码审查
bash ~/.claude/skills/codex-agent/scripts/codex-run.sh -r --uncommitted -d <工作目录> -o /tmp/review.txt

# 将结果写入文件（流水线模式）
bash ~/.claude/skills/codex-agent/scripts/codex-run.sh -f /tmp/codex-prompt.txt -o /tmp/codex-result.txt -d <工作目录>

# 续聊之前的会话（审查不通过后接着改，保留上下文）
bash ~/.claude/skills/codex-agent/scripts/codex-run.sh --resume <SESSION_ID> -f /tmp/codex-fix.txt -d <工作目录> -o /tmp/codex-result.txt
```

**Windows（重要：必须使用 powershell.exe 调用 .ps1 脚本）**：

> Claude Code 在 Windows 上使用 bash shell，但 .ps1 脚本不能用 bash 执行。
> 必须通过 `powershell.exe -ExecutionPolicy Bypass -File` 调用。
> 不要使用 `pwsh`（除非确认已安装 PowerShell 7）。

```bash
# 标准执行（从 bash 调用 PowerShell 脚本）
powershell.exe -ExecutionPolicy Bypass -File ~/.claude/skills/codex-agent/scripts/codex-run.ps1 -File /tmp/codex-prompt.txt -Dir <工作目录>

# 需要完整权限时
powershell.exe -ExecutionPolicy Bypass -File ~/.claude/skills/codex-agent/scripts/codex-run.ps1 -File /tmp/codex-prompt.txt -Sandbox dangerous -Dir <工作目录>

# 只读代码审查
powershell.exe -ExecutionPolicy Bypass -File ~/.claude/skills/codex-agent/scripts/codex-run.ps1 -Review -Uncommitted -Dir <工作目录> -Output /tmp/review.txt

# 续聊之前的会话
powershell.exe -ExecutionPolicy Bypass -File ~/.claude/skills/codex-agent/scripts/codex-run.ps1 -Resume <SESSION_ID> -File /tmp/codex-fix.txt -Dir <工作目录>
```

**Windows 注意事项**：
- 工作目录（-Dir）必须是 git 仓库，否则 codex CLI 会拒绝执行
- Prompt 文件必须是 UTF-8 编码（无 BOM），脚本内部已处理 BOM 问题
- 脚本已自动处理 npm/pnpm 安装的 .ps1 包装脚本兼容性问题

### 方式二：直接调用 codex CLI（备选）

当包装脚本出问题时，可直接调用：

```bash
# 代码编写/修复（通过 stdin 传递 prompt）
codex exec -s workspace-write -C <工作目录> -o /tmp/result.txt - < /tmp/prompt.txt

# 续聊（resume 不支持 -C 和 -s，需要先 cd，沙箱用 -c 设置）
cd <工作目录> && codex exec resume -c 'sandbox_mode="workspace-write"' -o /tmp/result.txt <SESSION_ID> - < /tmp/fix.txt

# 代码审查（review 子命令，不支持 -C，需要先 cd）
cd <工作目录> && codex exec review --uncommitted -o /tmp/review.txt
```

### 脚本参数

```
codex-run.sh / codex-run.ps1 [OPTIONS] [prompt...]

Bash:                                PowerShell:
  -m, --model <model>                  -Model <model>
  -d, --dir <directory>                -Dir <directory>
  -t, --timeout <seconds>              -Timeout <seconds>  (默认 900s)
  -s, --sandbox <mode>                 -Sandbox <mode>     (默认 workspace-write)
  -o, --output <file>                  -Output <file>
  -f, --file <file>                    -File <file>
      --resume <session_id>            -Resume <session_id>
  -r, --review                         -Review
      --uncommitted                    -Uncommitted
      --base <branch>                  -Base <branch>
```

**默认行为**：脚本默认跳过 git 仓库检查（`--skip-git-repo-check`），可在任何目录中使用。

**SESSION_ID**：每次运行结束时，脚本在 stderr 打印 `SESSION_ID: <id>`，传给 `--resume` 即可续聊。

## Codex CLI 关键参数映射（重要）

以下是 codex CLI 的**正确参数**，脚本已处理映射：

| 功能 | 正确参数 | 错误参数（不要用） |
|------|----------|---------------------|
| 只读沙箱 | `-s read-only` | `--read-only` |
| 完整权限 | `--dangerously-bypass-approvals-and-sandbox` | `--dangerously-auto-approve` |
| 工作区可写沙箱 | `-s workspace-write` | `--full-auto`（新版已删除） |
| 工作目录 | `-C <dir>`（仅 exec） | `--workdir` |
| 输出文件 | `-o <file>`（exec / resume / review 都支持） | - |
| stdin prompt | `- < file.txt`（末尾加 `-`） | `-f file.txt`（不存在此参数） |
| 续聊 | `codex exec resume <SESSION_ID>` | - |

## 沙箱模式说明

| 模式 | codex 参数 | 适用场景 |
|------|-----------|----------|
| `workspace-write` | `-c sandbox_mode="workspace-write"` | 大多数代码编写任务、图片生成 |
| `dangerous` | `--dangerously-bypass-approvals-and-sandbox` | 需要安装依赖、运行测试、修改配置 |
| `read-only` | `-s read-only` | 代码审查、分析 |

## 两种模式

### exec 模式（默认）- 代码编写/修复

用于代码编写、功能实现、bug 修复、重构等需要修改文件的任务。

```bash
# 通过脚本
bash ~/.claude/skills/codex-agent/scripts/codex-run.sh -f /tmp/prompt.txt -s dangerous -d <dir> -o /tmp/result.txt

# 直接调用（prompt 通过 stdin）
codex exec -s danger-full-access -C <dir> -o /tmp/result.txt - < /tmp/prompt.txt
```

### review 模式 - 代码审查

用于代码审查、安全检查、质量分析等只读任务。

```bash
# 审查未提交变更
bash ~/.claude/skills/codex-agent/scripts/codex-run.sh -r --uncommitted -d <dir> -o /tmp/review.txt

# 审查相对于某分支的变更
bash ~/.claude/skills/codex-agent/scripts/codex-run.sh -r --base main -d <dir> -o /tmp/review.txt

# 直接调用
cd <dir> && codex exec review --uncommitted -o /tmp/review.txt
```

**review 模式注意事项**：
- `codex exec review` 不支持 `-C`（工作目录）参数，需要先 `cd`
- `--uncommitted` 和自定义 prompt 不能同时使用
- review 不能续聊（`--resume` 和 `-r` 互斥）

## Prompt 构建指南

将用户需求转化为 Codex 友好的 prompt 时：

1. **明确任务** - 清晰描述要实现的功能或修复的问题
2. **提供上下文** - 相关文件路径、现有代码结构、依赖关系
3. **技术约束** - 语言版本、框架要求、编码规范
4. **验收标准** - 期望的输出、测试要求
5. **文件操作** - 明确指出要创建/修改的文件路径

参考 `references/prompt-templates.md` 获取完整模板。

## 输出捕获

exec 和 review 模式都使用 `-o` 参数：

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
| `command not found: codex` | PATH 未包含 pnpm 全局 bin | 脚本已把常见路径追加到 PATH 末尾兜底 |
| `Error loading config.toml` / 参数报错但手动执行正常 | 脚本找到了另一个旧版 codex | 用 `which -a codex` 检查，删掉旧版本 |
| `unexpected argument '--full-auto'` | 新版 codex 已删除该参数 | 改用 `-s workspace-write` |
| `unexpected argument '--read-only'` | 使用了错误的沙箱参数 | 正确参数是 `-s read-only` |
| `unexpected argument '-f'` | codex exec 不支持 -f | 使用 stdin：`codex exec ... - < file.txt` |
| `cannot be used with '[PROMPT]'` | review --uncommitted 和 prompt 冲突 | 二选一：用 --uncommitted 或自定义 prompt |
| Windows PS1 脚本启动 codex 失败 | npm/pnpm 安装的 codex 是 .ps1 包装脚本，Process.Start() 无法直接执行 | 脚本已自动处理：优先使用 .cmd 版本，否则通过 powershell.exe 间接执行 |

## 并行任务拆分（重要）

**Codex 模型运行时间较长（通常 5-15 分钟），可通过任务拆分 + 并行执行提升效率。**

### 执行策略

1. **分析任务** - 收到用户请求后，先分析是否可以拆分为多个独立子任务
2. **拆分原则**：
   - 按文件/模块拆分：不同文件的修改可以并行
   - 按功能拆分：独立功能（如 API + 测试）可以并行
   - 按层次拆分：前端组件 vs 后端逻辑 vs 数据库迁移
   - **不可拆分的情况**：子任务之间有强依赖（B 必须基于 A 的输出）
3. **并行执行** - 使用 Bash 工具的 `run_in_background: true` 模式启动多个后台任务。多个任务会修改同一个 git 仓库时，改用 `/ai-team` 的模式 C（每个 worker 一个 worktree，避免互相覆盖）
4. **汇总审查** - 所有子任务完成后，Claude 审查并整合结果

### 不拆分的情况

以下场景直接单任务执行，不做拆分：
- 任务本身很简单（单文件小改动）
- 子任务之间有强依赖关系
- 用户明确要求按顺序执行

## 任务路由

当用户请求包含以下关键词时，应路由到 codex-agent：
- 实现、编写、修复、重构、测试、代码、功能、API、后端、数据库、bug
- review、审查、检查代码、代码质量

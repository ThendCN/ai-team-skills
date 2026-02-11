---
name: codex-agent
description: "Codex AI 代理 - 代码编写与实现专家。支持代码编写、功能实现、bug 修复、重构、测试、代码审查。使用 /codex-agent <描述> 或 /codex <描述> 委派代码任务给 Codex。"
---

# Codex Agent - AI 团队代码实现专家

将代码编写和实现任务委派给 Codex，由 Claude Code 编排和审查。

## 用法

```
/codex-agent <代码任务描述>
/codex <代码任务描述>
```

也可由 Claude Code 在分析任务后自动委派（当任务涉及代码编写/实现/修复/重构/测试/审查时）。

## 执行方式

### 方式一：使用包装脚本（推荐）

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
codex-run.sh [OPTIONS] [prompt...]
  -m, --model <model>        模型覆盖（默认用 config.toml 配置）
  -d, --dir <directory>      工作目录
  -t, --timeout <seconds>    超时（默认 600s）
  -s, --sandbox <mode>       full-auto(默认) | dangerous | read-only
  -o, --output <file>        将最终消息写入文件
  -f, --file <file>          从文件读取 prompt（推荐）
  -r, --review               使用 review 模式（代码审查）
      --uncommitted          审查未提交的变更（仅 review 模式）
      --base <branch>        审查相对于指定分支的变更（仅 review 模式）
```

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

| 模式 | codex 参数 | 适用场景 |
|------|-----------|----------|
| `full-auto` | `--full-auto` | 大多数代码编写任务 |
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

# 直接调用（注意：review 输出在 stderr，需要 2>&1）
cd <dir> && codex exec review --uncommitted > /tmp/review.txt 2>&1
```

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

## 并行任务拆分（重要）

**Codex 模型运行时间较长（通常 5-15 分钟），可通过任务拆分 + 并行执行提升效率。**

### 执行策略

1. **分析任务** - 收到用户请求后，先分析是否可以拆分为多个独立子任务
2. **拆分原则**：
   - 按文件/模块拆分：不同文件的修改可以并行
   - 按功能拆分：独立功能（如 API + 测试）可以并行
   - 按层次拆分：前端组件 vs 后端逻辑 vs 数据库迁移
   - **不可拆分的情况**：子任务之间有强依赖（B 必须基于 A 的输出）
3. **并行执行** - 使用 Bash 工具的 `run_in_background: true` 模式启动多个后台任务
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

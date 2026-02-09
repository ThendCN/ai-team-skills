---
name: codex-agent
description: "Codex (gpt-5.2-codex) AI 代理 - 代码编写与实现专家。支持代码编写、功能实现、bug 修复、重构、测试。使用 /codex-agent <描述> 或 /codex <描述> 委派代码任务给 Codex。"
---

# Codex Agent - AI 团队代码实现专家

将代码编写和实现任务委派给 Codex (gpt-5.2-codex)，由 Claude Code 编排和审查。

## 用法

```
/codex-agent <代码任务描述>
/codex <代码任务描述>
```

也可由 Claude Code 在分析任务后自动委派（当任务涉及代码编写/实现/修复/重构/测试时）。

## 执行方式

**推荐：使用 `-f` 文件模式传递 prompt**

```bash
# 标准执行（full-auto 沙箱，安全默认）
bash .claude/skills/codex-agent/scripts/codex-run.sh -f /tmp/codex-prompt.txt -d <工作目录>

# 需要完整权限时（如安装依赖、修改系统文件）
bash .claude/skills/codex-agent/scripts/codex-run.sh -f /tmp/codex-prompt.txt -s dangerous -d <工作目录>

# 将结果写入文件（流水线模式）
bash .claude/skills/codex-agent/scripts/codex-run.sh -f /tmp/codex-prompt.txt -o /tmp/codex-result.txt -d <工作目录>
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
```

## 沙箱模式说明

| 模式 | 说明 | 适用场景 |
|------|------|----------|
| `full-auto` | 沙箱内自动执行（默认） | 大多数代码编写任务 |
| `dangerous` | 完整权限，自动批准所有操作 | 需要安装依赖、修改配置 |
| `read-only` | 只读模式 | 代码审查、分析 |

## Prompt 构建指南

将用户需求转化为 Codex 友好的 prompt 时：

1. **明确任务** - 清晰描述要实现的功能或修复的问题
2. **提供上下文** - 相关文件路径、现有代码结构、依赖关系
3. **技术约束** - 语言版本、框架要求、编码规范
4. **验收标准** - 期望的输出、测试要求
5. **文件操作** - 明确指出要创建/修改的文件路径

参考 `references/prompt-templates.md` 获取完整模板。

## 输出捕获

使用 `-o` 参数将 Codex 的最终输出写入文件，便于 Claude 读取结果：

```bash
bash .claude/skills/codex-agent/scripts/codex-run.sh \
  -f /tmp/codex-prompt.txt \
  -o /tmp/codex-result.txt \
  -d ./project
```

Claude 随后读取 `/tmp/codex-result.txt` 获取执行结果。

## 流水线集成

作为流水线第二步（实现阶段）时：
1. Claude 读取 Gemini 生成的 UI 代码文件
2. 提取关键设计信息（组件结构、样式、交互逻辑）
3. 构建实现 prompt，包含 UI 设计上下文
4. 调用 codex-run.sh 实现完整业务逻辑
5. Claude 审查最终输出，整合并返回用户

### 上下文传递
- Gemini 输出的文件已在工作目录中，Codex 可直接访问
- Prompt 中应包含 Gemini 生成的文件路径和关键设计决策
- 使用 `-o` 输出文件供 Claude 读取最终结果摘要

## 任务路由

当用户请求包含以下关键词时，应路由到 codex-agent：
- 实现、编写、修复、重构、测试、代码、功能、API、后端、数据库、bug

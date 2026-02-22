---
name: gemini-agent
description: "Gemini (gemini-3-pro-preview) AI 代理 - UI 设计与前端开发专家。gemini-ui 的增强版，支持包装脚本、错误处理、流水线模式。触发条件：UI 设计、前端组件、页面布局、视觉设计、样式美化。使用 /gemini-agent <描述> 或 /design-ui <描述> 委派 UI 设计任务给 Gemini。"
---

# Gemini Agent - AI 团队 UI 设计专家

将 UI 设计和前端开发任务委派给 Gemini (gemini-3-pro-preview)，由 Claude Code 编排和审查。

## 用法

```
/gemini-agent <UI 设计描述>
/design-ui <UI 设计描述>
```

也可由 Claude Code 在分析任务后自动委派（当任务涉及 UI/设计/组件/页面/布局/样式时）。

## 执行方式

**推荐：使用 `-f` 文件模式传递 prompt（避免 shell 转义问题）**

**Linux / macOS (Bash)**：
```bash
bash .claude/skills/gemini-agent/scripts/gemini-run.sh -f /tmp/gemini-prompt.txt -d <工作目录>
```

**Windows（重要：必须使用 powershell.exe 调用 .ps1 脚本）**：

> Claude Code 在 Windows 上使用 bash shell，但 .ps1 脚本不能用 bash 执行。
> 必须通过 `powershell.exe -ExecutionPolicy Bypass -File` 调用。
> 不要使用 `pwsh`（除非确认已安装 PowerShell 7）。
> 不要使用 `-Command "& 'script.ps1'"` 形式（转义问题多）。

```bash
# 从 bash 调用 PowerShell 脚本
powershell.exe -ExecutionPolicy Bypass -File ~/.claude/skills/gemini-agent/scripts/gemini-run.ps1 -File /tmp/gemini-prompt.txt -Dir <工作目录>
```

**Windows 注意事项**：
- Prompt 文件必须是 UTF-8 编码（无 BOM）
- 脚本已自动处理 npm/pnpm 安装的 .ps1 包装脚本兼容性问题

### 脚本参数

```
gemini-run.sh / gemini-run.ps1 [OPTIONS] [prompt...]

Bash:                                PowerShell:
  -m, --mode <yolo|prompt>             -Mode <yolo|prompt>
  --model <model>                      -Model <model>
  -d, --dir <directory>                -Dir <directory>
  -t, --timeout <seconds>              -Timeout <seconds>
  -f, --file <file>                    -File <file>
```

## Prompt 构建指南

将用户需求转化为 Gemini 友好的 prompt 时，遵循以下结构：

1. **角色设定** - 在 prompt 开头明确要求使用 gemini-3-pro-preview 模型能力进行 UI 设计，例如：「你是 Gemini Pro，一个顶级 UI 设计师和前端开发专家，擅长创建高品质、现代化的用户界面。」
2. **任务描述** - 清晰描述要生成的 UI
3. **技术栈** - 明确框架（React/Vue/HTML）和样式方案（Tailwind/CSS）
4. **代码规范** - 语义化 HTML、可访问性、响应式、TypeScript
5. **设计风格** - 视觉要求（现代简洁、间距圆角、微交互）
6. **输出要求** - 直接生成代码，写入指定文件路径

**关键：prompt 中应强调利用 Pro 模型的高级设计能力**，包括精细的视觉层次、配色方案、动画细节等。

参考 `references/prompt-templates.md` 获取完整模板。

## 输出处理

Gemini 生成的文件直接写入工作目录。Claude Code 应：
1. 检查 Gemini 生成了哪些文件（通过 git status 或 ls）
2. 读取并审查生成的代码质量
3. 必要时进行微调和修正

## 流水线集成

作为流水线第一步（设计阶段）时：
1. Claude 分析需求，构建 UI 设计 prompt
2. 调用 gemini-run.sh（或 Windows 上的 gemini-run.ps1）生成 UI 代码
3. Claude 读取生成的文件，提取关键设计信息
4. 将 UI 设计上下文传递给下一步（codex-agent 实现业务逻辑）

### 输出约定
- 生成的文件应在工作目录的合理位置（如 `src/components/`, `src/pages/`）
- 文件命名遵循项目约定（PascalCase for React, kebab-case for Vue）

## 与 gemini-ui 的关系

gemini-agent 是 gemini-ui 的增强版：
- **gemini-ui**: 简单快速的 UI 生成，直接调用 gemini CLI
- **gemini-agent**: 完整的包装脚本、错误处理、超时控制、流水线支持

两者共存，简单任务可用 gemini-ui，复杂任务或流水线模式用 gemini-agent。

## 任务路由

当用户请求包含以下关键词时，应路由到 gemini-agent：
- 设计、UI、组件、页面、布局、样式、美化、前端、界面、视觉

**注意**：如果任务涉及 UI + 后端逻辑的全栈开发，考虑使用 `/ai-team` 进行多 Agent 协作。

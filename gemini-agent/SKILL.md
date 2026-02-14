---
name: gemini-agent
description: "Gemini (gemini-3-pro-preview) AI 代理 - UI 设计与前端开发专家。模型优势：多模态原生支持（可从草图/截图生成 UI）、快速原型生成（'vibe coding'）、1M 超大上下文窗口、视觉设计能力最强、成本最低。适用场景：UI 设计、前端组件、页面布局、视觉设计、样式美化、从设计稿生成代码、快速前端原型。不适用场景：后端逻辑（用 /codex-agent）、复杂多文件重构（Claude 自己处理）、终端/CI-CD 操作（用 /codex-agent）。使用 /gemini-agent <描述> 或 /design-ui <描述> 委派 UI 设计任务给 Gemini。"
---

# Gemini Agent - AI 团队 UI 设计专家

将 UI 设计和前端开发任务委派给 Gemini (gemini-3-pro-preview)，由 Claude Code 编排和审查。

## 用法

```
/gemini-agent <UI 设计描述>
/design-ui <UI 设计描述>
```

也可由 Claude Code 在分析任务后自动委派（当任务涉及 UI/设计/组件/页面/布局/样式时）。

## 模型优势与路由指南

### 为什么选择 Gemini 而非其他 Agent

| 场景 | 推荐 | 原因 |
|------|------|------|
| UI 组件设计与前端页面 | ✅ Gemini | 视觉设计能力最强，多模态原生支持 |
| 从草图/截图/设计稿生成 UI 代码 | ✅ Gemini | 原生图像理解，可直接将视觉输入转为代码 |
| 快速前端原型（"vibe coding"） | ✅ Gemini | 从高层描述快速生成完整应用原型 |
| 响应式布局与样式美化 | ✅ Gemini | 精细的视觉层次、配色、动画细节 |
| 后端逻辑/API 实现 | ❌ Codex | Codex 代码实现能力更强 |
| 复杂业务逻辑/算法 | ❌ Claude 自己 | Claude 复杂推理能力更强 |
| 终端操作/CI-CD | ❌ Codex | Codex 终端能力最强 |
| 多文件重构 | ❌ Claude 自己 | Claude 跨文件一致性最佳 |

### Gemini 模型特点

- **多模态原生**：可处理文本、图像、音频、视频，适合从视觉输入生成 UI
- **超大上下文**：1M tokens 上下文窗口，可容纳大型代码库
- **快速生成**：短 prompt 响应最快，适合快速迭代
- **成本最低**：$2/$12 per million tokens，比 Claude 便宜 60%
- **Google 搜索集成**：可实时查询最新文档和最佳实践
- **注意事项**：复杂多步骤任务和模糊指令下输出可能不稳定，建议 prompt 尽量具体明确

## 执行方式

**推荐：使用 `-f` 文件模式传递 prompt（避免 shell 转义问题）**

```bash
# Linux / macOS
bash .claude/skills/gemini-agent/scripts/gemini-run.sh -f /tmp/gemini-prompt.txt -d <工作目录>

# Windows (PowerShell)
pwsh .claude/skills/gemini-agent/scripts/gemini-run.ps1 -File $env:TEMP\gemini-prompt.txt -Dir <工作目录>
```

```batch
# Windows (CMD) - 原生批处理脚本（无需 PowerShell）
cmd /c .claude\skills\gemini-agent\scripts\gemini-run.cmd -f %TEMP%\gemini-prompt.txt -d <工作目录>
```

### 脚本参数

```
gemini-run.sh / gemini-run.ps1 / gemini-run.cmd [OPTIONS] [prompt...]

Bash:                                PowerShell:                          CMD:
  -m, --mode <yolo|prompt>             -Mode <yolo|prompt>                  -m / --mode <yolo|prompt>
  --model <model>                      -Model <model>                       --model <model>
  -d, --dir <directory>                -Dir <directory>                     -d / --dir <directory>
  -t, --timeout <seconds>              -Timeout <seconds>                   -t / --timeout <seconds>
  -f, --file <file>                    -File <file>                         -f / --file <file>
```

### CMD 限制说明

- CMD 命令行长度上限 8191 字符，长 prompt 必须使用 `-f` 文件模式
- gemini CLI 接受 prompt 作为命令行参数（非 stdin），受 CMD 字符限制影响
- 超时使用 `ping -n` 计时的 watchdog 进程，精度为秒级
- 超时 kill 通过进程名（`taskkill /im`），可能影响同名进程

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
- 原型、mockup、草图、截图转代码、设计稿
- 响应式、动画、配色、主题

**不应路由到 gemini-agent 的情况**：
- 后端逻辑、API、数据库操作 → 路由到 `/codex-agent`
- 复杂业务逻辑或算法实现 → Claude 自己处理或 `/codex-agent`
- 终端操作、CI/CD、部署 → 路由到 `/codex-agent`
- 多文件重构、架构调整 → Claude 自己处理

---
name: ai-team
description: "AI 团队协作流水线。自动编排 Claude(Lead) + Codex(代码) + Gemini(UI) 多 Agent 协作。使用 /ai-team <任务描述> 启动团队协作。"
---

# AI Team - 多 Agent 协作流水线

自动编排 Claude (Team Lead) + Codex (代码) + Gemini (UI) 的多 Agent 协作流水线。通过后台任务并行执行，适用于复杂项目。

## 用法

```
/ai-team <复杂任务描述>
/team <复杂任务描述>
```

## 何时使用

**使用 AI Team**（需要多 agent 协作）：
- 全栈功能开发（UI + 后端 + 测试）
- 大型重构（多文件、多模块并行）
- UI 设计 + 逻辑实现的联动任务
- 代码审查 + 修复的流水线

**不使用 AI Team**（单 agent 即可）：
- 单文件修改 → `/codex-agent`
- 纯 UI 任务 → `/gemini-agent`
- 简单 bug 修复 → Claude 自己处理

## 团队角色

| 角色 | 实现方式 | 职责 |
|------|----------|------|
| Team Lead | Claude (你自己) | 任务拆分、分配、审查、整合、质量把控 |
| Codex Worker | 后台 Bash 调用 codex CLI | 代码编写、修复、审查、测试 |
| Gemini Worker | 后台 Bash 调用 gemini CLI | UI 设计、前端组件、样式 |

## 执行流程

### Phase 1: 分析与拆分

1. 分析用户任务，识别子任务类型：
   - 前端/UI → Gemini Worker
   - 后端/逻辑/测试 → Codex Worker
   - 全栈 → 两者协作
2. 确定依赖关系（独立任务并行，有依赖的串行）
3. 识别项目上下文（工作目录、技术栈、测试命令）

### Phase 2: 准备任务

1. 创建临时文件目录（`{workdir}/.tmp/`，如果不存在）
2. 为每个子任务创建 prompt 文件（`{workdir}/.tmp/task-{id}-prompt.txt`）
3. 准备输出文件路径（`{workdir}/.tmp/task-{id}-output.txt`）
4. 确定执行顺序（并行 vs 串行）

**注意**：使用项目目录下的 `.tmp/` 而不是系统 `/tmp/`，以确保跨平台兼容性和访问控制。

### Phase 3: 启动 Workers

使用 Bash tool 的 `run_in_background: true` 模式并行启动多个 workers。

**示例**（后台并行启动）：
```bash
# Linux/macOS
bash ~/.claude/skills/codex-agent/scripts/codex-run.sh \
  -f <workdir>/.tmp/task-1-prompt.txt \
  -o <workdir>/.tmp/task-1-output.txt \
  -s dangerous -d <workdir>
# (run_in_background: true)

# Windows
powershell.exe -ExecutionPolicy Bypass -File ~/.claude/skills/codex-agent/scripts/codex-run.ps1 \
  -File <workdir>/.tmp/task-1-prompt.txt \
  -Output <workdir>/.tmp/task-1-output.txt \
  -Sandbox dangerous -Dir <workdir>
# (run_in_background: true)
```

详细命令和模板参见 `references/pipeline-templates.md`。

### Phase 4: 监控与收集

1. 使用 TaskOutput 工具检查后台任务状态
2. 读取输出文件获取执行结果
3. 检查工作目录中生成的文件

### Phase 5: 审查与整合

1. Team Lead 审查每个 worker 的输出
2. 检查代码质量、一致性、集成问题
3. 必要时进行微调和修正
4. 运行测试验证整体功能

## 上下文传递

当一个 worker 的输出需要传递给另一个 worker 时：

1. **文件路径** - 前序 worker 生成的文件已在工作目录中，后续 worker 可直接读取
2. **摘要传递** - Team Lead 在后续任务的 prompt 中包含前序输出的关键信息
3. **设计决策** - 在后续任务的 prompt 中包含前序的设计决策和接口定义

## 错误处理

- Worker 失败 → 读取输出文件分析错误，修改 prompt 后重新执行
- CLI 超时 → 拆分为更小的子任务
- 依赖冲突 → Team Lead 手动解决后再启动依赖任务
- 后台任务卡住 → 使用 TaskStop 终止，分析原因后重试

## 流水线模式

### 模式 A: UI → 实现（串行）
Gemini Worker 设计 UI → Team Lead 审查 → Codex Worker 实现逻辑 → 测试

### 模式 B: 审查 → 修复（串行）
Codex Worker 审查代码 → Team Lead 分析 → Codex Worker 修复问题 → 测试

### 模式 C: 多模块并行
并行启动多个 Codex/Gemini Workers → Team Lead 整合 → 集成测试

详细流水线模板参见 `references/pipeline-templates.md`。

## 最佳实践

### Prompt 设计
- 明确任务目标和验收标准
- 提供足够的上下文（文件路径、技术栈）
- 指定输出格式和文件位置

### 任务拆分
**可并行**：不同模块/文件的独立功能、UI vs 后端逻辑
**必须串行**：有明确依赖关系、需要审查后再继续的流程

### 错误恢复
Worker 失败时读取输出文件分析错误，调整 prompt 后重试。超时则拆分为更小的子任务。

### 质量把控
Team Lead 负责审查代码风格、安全性、性能、测试覆盖率。不要盲目信任 worker 输出。

## 技术限制

1. **并行度**：建议同时运行的 worker 不超过 3-4 个（避免资源竞争）
2. **任务粒度**：单个 worker 任务应在 10-20 分钟内完成
3. **文件冲突**：并行任务不应修改相同的文件
4. **依赖管理**：复杂依赖关系建议使用串行模式

**注意**：包装脚本默认跳过 git 仓库检查，可在任何目录中使用。

## 临时文件管理

### 临时目录位置

使用项目工作目录下的 `.tmp/` 文件夹存储临时文件：
- ✅ 跨平台兼容（相对路径）
- ✅ 控制访问范围（在项目目录内）
- ✅ 便于调试和清理
- ✅ 避免权限问题

### 创建临时目录

在启动 workers 之前，确保临时目录存在：
```bash
Bash tool: mkdir -p {workdir}/.tmp
```

### .gitignore 配置

建议在项目的 `.gitignore` 中添加：
```
# AI Team 临时文件
.tmp/
```

这样可以避免临时文件被提交到版本控制。

### 清理临时文件

任务完成后，可以选择清理临时文件：
```bash
# 清理所有临时文件
Bash tool: rm -rf {workdir}/.tmp

# 或只清理特定任务的文件
Bash tool: rm {workdir}/.tmp/task-*
```

## 与单 Agent 模式的对比

| 场景 | 单 Agent | AI Team |
|------|----------|---------|
| 单文件小改动 | ✅ 快速直接 | ❌ 过度设计 |
| 多模块重构 | ❌ 串行慢 | ✅ 并行快 |
| 全栈功能 | ❌ 需要多次调用 | ✅ 一次性完成 |
| 简单 UI | ✅ 直接用 /gemini-agent | ❌ 不需要团队 |
| 代码审查 + 修复 | ❌ 需要手动传递上下文 | ✅ 自动流水线 |

## 故障排查

| 问题 | 可能原因 | 解决方案 |
|------|----------|----------|
| Worker 无输出 | 后台任务失败 | 使用 TaskOutput 检查错误信息 |
| 文件冲突 | 并行任务修改同一文件 | 改为串行执行或拆分文件 |
| 超时 | 任务过于复杂 | 拆分为更小的子任务 |
| 集成失败 | 接口不匹配 | Team Lead 手动调整或重新生成 |
| 输出文件为空 | Prompt 不清晰或 CLI 错误 | 检查 prompt 质量，查看 CLI 错误日志 |

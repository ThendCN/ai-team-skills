# AI Team 流水线模板

本文档提供 AI Team 多 Agent 协作的实用模板。

## 架构说明

AI Team 使用 Bash tool 的后台模式启动多个 workers：
- **Codex Worker**: 通过 codex-run.sh/ps1 脚本调用 codex CLI
- **Gemini Worker**: 通过 gemini-run.sh/ps1 脚本调用 gemini CLI
- **Team Lead (Claude)**: 负责任务拆分、启动 workers、监控、审查、整合

## 模板 1: UI → 实现（Gemini → Codex，串行）

适用于全栈功能开发，先设计 UI，再实现后端逻辑。

### Phase 1: Gemini 设计 UI

**准备临时目录**：
```bash
Bash tool: mkdir -p {workdir}/.tmp
```

**准备 Prompt**：
```bash
Write tool: {workdir}/.tmp/gemini-prompt.txt
内容:
---
你是 Gemini Pro，一个顶级 UI 设计师和前端开发专家。

项目工作目录: {workdir}
技术栈: {tech_stack}

任务: {task_description}

要求:
1. 设计完整的 UI 交互流程
2. 输出可直接使用的前端代码（React/Vue/HTML）
3. 遵循项目现有的代码风格
4. 包含必要的交互逻辑和状态管理
5. 使用 Tailwind CSS 或项目指定的样式方案

输出文件: {output_file_path}
---
```

**启动 Gemini Worker**：
```bash
# Linux/macOS
Bash tool:
  command: "bash ~/.claude/skills/gemini-agent/scripts/gemini-run.sh -f {workdir}/.tmp/gemini-prompt.txt -d {workdir}"
  description: "启动 Gemini Worker 设计 UI"

# Windows
Bash tool:
  command: "powershell.exe -ExecutionPolicy Bypass -File ~/.claude/skills/gemini-agent/scripts/gemini-run.ps1 -File {workdir}/.tmp/gemini-prompt.txt -Dir {workdir}"
  description: "启动 Gemini Worker 设计 UI"
```

**收集结果**：
```bash
# 查看生成的文件
Bash tool: git status
Bash tool: ls -la src/components/

# 读取生成的 UI 代码
Read tool: {generated_ui_file}
```

### Phase 2: Codex 实现后端逻辑

**准备 Prompt**（包含 Gemini 输出的上下文）：
```bash
Write tool: {workdir}/.tmp/codex-prompt.txt
内容:
---
基于已有的 UI 设计实现后端逻辑。

项目工作目录: {workdir}
技术栈: {tech_stack}

UI 文件（由 Gemini 生成）: {gemini_output_files}
UI 设计要点:
- {design_point_1}
- {design_point_2}
- {design_point_3}

任务: {task_description}

要求:
1. 实现 UI 所需的后端接口/API
2. 如需数据库变更，创建 migration 文件
3. 实现业务逻辑和数据验证
4. 添加单元测试和集成测试
5. 遵循项目编码规范

测试命令: {test_command}
---
```

**启动 Codex Worker**：
```bash
# Linux/macOS
Bash tool:
  command: "bash ~/.claude/skills/codex-agent/scripts/codex-run.sh -f {workdir}/.tmp/codex-prompt.txt -s dangerous -o {workdir}/.tmp/codex-output.txt -d {workdir}"
  description: "启动 Codex Worker 实现后端逻辑"

# Windows
Bash tool:
  command: "powershell.exe -ExecutionPolicy Bypass -File ~/.claude/skills/codex-agent/scripts/codex-run.ps1 -File {workdir}/.tmp/codex-prompt.txt -Sandbox dangerous -Output {workdir}/.tmp/codex-output.txt -Dir {workdir}"
  description: "启动 Codex Worker 实现后端逻辑"
```

**收集结果**：
```bash
# 读取 Codex 输出
Read tool: {workdir}/.tmp/codex-output.txt

# 查看生成的文件
Bash tool: git status
```

### Phase 3: Team Lead 审查整合

```bash
# 运行测试
Bash tool: {test_command}

# 审查代码质量
# - UI 和后端接口是否匹配
# - 错误处理是否完善
# - 测试覆盖率是否足够
```

## 模板 2: 审查 → 修复（Codex Review → Codex Fix，串行）

适用于代码质量改进和 bug 修复。

### Phase 1: Codex 审查代码

**启动 Review Worker**：
```bash
# Linux/macOS
Bash tool:
  command: "bash ~/.claude/skills/codex-agent/scripts/codex-run.sh -r --uncommitted -o {workdir}/.tmp/review-output.txt -d {workdir}"
  description: "启动 Codex Worker 审查代码"

# Windows
Bash tool:
  command: "powershell.exe -ExecutionPolicy Bypass -File ~/.claude/skills/codex-agent/scripts/codex-run.ps1 -Review -Uncommitted -Output {workdir}/.tmp/review-output.txt -Dir {workdir}"
  description: "启动 Codex Worker 审查代码"
```

**分析审查报告**：
```bash
Read tool: {workdir}/.tmp/review-output.txt

# Team Lead 提取关键问题：
# - 安全漏洞
# - 性能问题
# - 代码质量问题
# - 逻辑错误
```

### Phase 2: Codex 修复问题

**准备修复 Prompt**（基于审查结果）：
```bash
Write tool: {workdir}/.tmp/fix-prompt.txt
内容:
---
根据代码审查报告修复以下问题：

审查报告摘要:
{review_summary}

关键问题:
1. {issue_1} - 严重性: {severity_1}
2. {issue_2} - 严重性: {severity_2}
3. {issue_3} - 严重性: {severity_3}

修复要求:
1. 对每个问题提供清晰的修复说明
2. 修改相关文件
3. 添加测试验证修复效果
4. 确保不引入新问题

测试命令: {test_command}
---
```

**启动 Fix Worker**：
```bash
# Linux/macOS
Bash tool:
  command: "bash ~/.claude/skills/codex-agent/scripts/codex-run.sh -f {workdir}/.tmp/fix-prompt.txt -s dangerous -o {workdir}/.tmp/fix-output.txt -d {workdir}"
  description: "启动 Codex Worker 修复问题"

# Windows
Bash tool:
  command: "powershell.exe -ExecutionPolicy Bypass -File ~/.claude/skills/codex-agent/scripts/codex-run.ps1 -File {workdir}/.tmp/fix-prompt.txt -Sandbox dangerous -Output {workdir}/.tmp/fix-output.txt -Dir {workdir}"
  description: "启动 Codex Worker 修复问题"
```

**验证修复**：
```bash
# 读取修复结果
Read tool: {workdir}/.tmp/fix-output.txt

# 运行测试
Bash tool: {test_command}

# 确认问题已解决
```

## 模板 3: 多模块并行（Codex × N，并行）

适用于多个独立模块同时开发。

### Phase 1: 准备所有子任务 Prompts

```bash
# 创建临时目录
Bash tool: mkdir -p {workdir}/.tmp

# 模块 A
Write tool: {workdir}/.tmp/task-a-prompt.txt
内容:
---
实现 {module_a_name} 模块。

项目工作目录: {workdir}
技术栈: {tech_stack}

功能要求:
{requirements_a}

文件结构:
- {file_a1}: {description_a1}
- {file_a2}: {description_a2}

注意: 此模块与 {module_b_name}, {module_c_name} 并行开发，
请确保接口定义清晰，避免命名冲突。

测试命令: {test_command_a}
---

# 模块 B
Write tool: {workdir}/.tmp/task-b-prompt.txt
内容: (类似结构)

# 模块 C (UI)
Write tool: {workdir}/.tmp/task-c-prompt.txt
内容: (类似结构)
```

### Phase 2: 并行启动所有 Workers

```bash
# Worker A - Codex 实现模块 A (后台)
# Linux/macOS: bash ~/.claude/skills/codex-agent/scripts/codex-run.sh -f {workdir}/.tmp/task-a-prompt.txt -o {workdir}/.tmp/task-a-output.txt -s dangerous -d {workdir}
# Windows:
Bash tool (run_in_background: true):
  command: "powershell.exe -ExecutionPolicy Bypass -File ~/.claude/skills/codex-agent/scripts/codex-run.ps1 -File {workdir}/.tmp/task-a-prompt.txt -Output {workdir}/.tmp/task-a-output.txt -Sandbox dangerous -Dir {workdir}"
  description: "启动 Codex Worker A 实现模块 A"

# Worker B - Codex 实现模块 B (后台)
# Linux/macOS: bash ~/.claude/skills/codex-agent/scripts/codex-run.sh -f {workdir}/.tmp/task-b-prompt.txt -o {workdir}/.tmp/task-b-output.txt -s dangerous -d {workdir}
# Windows:
Bash tool (run_in_background: true):
  command: "powershell.exe -ExecutionPolicy Bypass -File ~/.claude/skills/codex-agent/scripts/codex-run.ps1 -File {workdir}/.tmp/task-b-prompt.txt -Output {workdir}/.tmp/task-b-output.txt -Sandbox dangerous -Dir {workdir}"
  description: "启动 Codex Worker B 实现模块 B"

# Worker C - Gemini 设计 UI (后台)
# Linux/macOS: bash ~/.claude/skills/gemini-agent/scripts/gemini-run.sh -f {workdir}/.tmp/task-c-prompt.txt -d {workdir}
# Windows:
Bash tool (run_in_background: true):
  command: "powershell.exe -ExecutionPolicy Bypass -File ~/.claude/skills/gemini-agent/scripts/gemini-run.ps1 -File {workdir}/.tmp/task-c-prompt.txt -Dir {workdir}"
  description: "启动 Gemini Worker C 设计 UI"
```

### Phase 3: 监控所有任务

```bash
# 检查任务状态（非阻塞）
TaskOutput tool: task_id="{task_a_id}", block=false, timeout=1000
TaskOutput tool: task_id="{task_b_id}", block=false, timeout=1000
TaskOutput tool: task_id="{task_c_id}", block=false, timeout=1000

# 等待所有任务完成（阻塞）
TaskOutput tool: task_id="{task_a_id}", block=true, timeout=600000
TaskOutput tool: task_id="{task_b_id}", block=true, timeout=600000
TaskOutput tool: task_id="{task_c_id}", block=true, timeout=600000
```

### Phase 4: 收集和整合结果

```bash
# 读取所有输出
Read tool: {workdir}/.tmp/task-a-output.txt
Read tool: {workdir}/.tmp/task-b-output.txt

# 查看生成的文件
Bash tool: git status

# Team Lead 审查：
# - 模块间接口是否匹配
# - 命名是否有冲突
# - 代码风格是否一致
```

### Phase 5: 集成测试

```bash
# 运行集成测试
Bash tool: {integration_test_command}

# 如有问题，准备修复 prompt 并重新执行
```

## 最佳实践

### Prompt 设计原则

1. **明确性**: 清晰描述任务目标和验收标准
2. **上下文**: 提供足够的项目信息（技术栈、文件路径、现有代码）
3. **约束**: 明确技术约束和编码规范
4. **输出**: 指定期望的输出格式和文件位置
5. **测试**: 包含测试命令和验证方法

### 任务拆分原则

**可并行**：
- 不同模块/文件的独立功能
- UI 设计 vs 后端逻辑（如果接口已定义）
- 多个独立的 bug 修复

**必须串行**：
- 有明确依赖关系（B 需要 A 的输出）
- 需要审查后再继续的流程
- 共享状态的修改（避免冲突）

### 错误处理

1. **Worker 失败**: 读取输出文件分析错误，调整 prompt 后重试
2. **超时**: 拆分为更小的子任务
3. **文件冲突**: 改为串行执行或调整文件分配
4. **集成失败**: Team Lead 手动调整或重新生成

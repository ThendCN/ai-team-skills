---
name: ai-team
description: "AI 团队协作流水线。自动编排 Claude(Lead) + Codex(代码) + Gemini(UI) 多 Agent 协作。使用 /ai-team <任务描述> 启动团队协作。"
---

# AI Team - 多 Agent 协作流水线

自动编排 Claude (Team Lead) + Codex Worker (代码) + Gemini Worker (UI) 的多 Agent 协作流水线。适用于任何项目。

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
- 单文件修改 → `/codex`
- 纯 UI 任务 → `/gemini-agent`
- 简单 bug 修复 → Claude 自己处理

## 团队角色

| 角色 | Agent | 职责 |
|------|-------|------|
| Team Lead | Claude (你自己) | 任务拆分、分配、审查、整合、质量把控 |
| codex-worker | 自定义 Agent | 代码编写、修复、审查、测试（通过 Codex CLI） |
| gemini-worker | 自定义 Agent | UI 设计、前端组件、样式（通过 Gemini CLI） |

## 执行流程

### Phase 1: 分析与拆分

1. 分析用户任务，识别子任务类型：
   - 前端/UI → gemini-worker
   - 后端/逻辑/测试 → codex-worker
   - 全栈 → 两者协作
2. 确定依赖关系（独立任务并行，有依赖的串行）
3. 识别项目上下文（工作目录、技术栈、测试命令）

### Phase 2: 创建团队

```
1. TeamCreate → "ai-team-{timestamp}"
2. TaskCreate → 创建所有子任务（含依赖）
3. Task tool → 启动 worker（subagent_type: "codex-worker" / "gemini-worker"）
4. TaskUpdate → 分配任务
5. SendMessage → 发送项目上下文
```

### Phase 3: 执行与监控

- Worker 自主执行，完成后通过 SendMessage 汇报
- Team Lead 审查结果
- 依赖任务解锁后分配给下一个 worker
- 处理 worker 间的上下文传递

### Phase 4: 整合与交付

- 所有任务完成 → 最终审查
- 运行测试验证
- 向用户汇报结果
- shutdown_request 关闭 worker → TeamDelete 清理

## 启动 Worker 模板

```
Task tool:
  subagent_type: "codex-worker"
  team_name: "{team_name}"
  name: "codex-worker"
  prompt: |
    你是 AI Team 的 Codex 工作者。
    团队: {team_name}
    你的名字: codex-worker

    项目工作目录: {workdir}
    项目信息: {project_context}

    请查看 TaskList 获取分配给你的任务，然后开始工作。
    完成后用 TaskUpdate 标记 completed，
    并通过 SendMessage 向 team-lead 汇报。
```

## 上下文传递

当一个 worker 的输出需要传递给另一个 worker 时：

1. **文件路径** - 前序 worker 生成的文件已在工作目录中，后续 worker 可直接读取
2. **摘要传递** - Team Lead 在 SendMessage 中包含前序输出的关键信息
3. **任务描述** - 在后续任务的 description 中包含前序的设计决策和接口定义

## 错误处理

- Worker 失败 → 分析原因，修改 prompt 后重新分配
- CLI 超时 → 拆分为更小的子任务
- 依赖冲突 → Team Lead 手动解决
- Worker 无响应 → shutdown_request 后重启

## 流水线模式

### 模式 A: UI → 实现（串行）
```
gemini-worker 设计 UI → Team Lead 审查 → codex-worker 实现逻辑 → 测试
```

### 模式 B: 审查 → 修复（串行）
```
codex-worker 审查代码 → Team Lead 确认 → codex-worker 修复问题 → 测试
```

### 模式 C: 多模块并行
```
codex-worker-1 实现模块 A ─┐
codex-worker-2 实现模块 B ─┤→ Team Lead 整合 → 集成测试
gemini-worker 设计 UI    ─┘
```

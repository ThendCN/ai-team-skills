---
name: ai-team
description: "AI 团队协作流水线。自动编排 Claude(Lead) + Codex(代码) + Gemini(UI) + 配图多 Agent 协作，带交叉审查门禁和 worktree 并行隔离。使用 /ai-team <任务描述> 启动团队协作。"
---

# AI Team - 多 Agent 协作流水线

自动编排 Claude (Team Lead) + Codex Worker (代码) + Gemini Worker (UI) + Image Worker (配图) 的多 Agent 协作流水线。适用于任何项目。

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
- 页面需要配图、图标、插画素材

**不使用 AI Team**（单 agent 即可）：
- 单文件修改 → `/codex`
- 纯 UI 任务 → `/gemini-agent`
- 简单 bug 修复 → Claude 自己处理

## 团队角色

| 角色 | Agent | 职责 |
|------|-------|------|
| Team Lead | Claude (你自己) | 任务拆分、分配、审查门禁、合并、质量把控 |
| codex-worker | 自定义 Agent | 代码编写、修复、审查、测试（通过 Codex CLI） |
| gemini-worker | 自定义 Agent | UI 设计、前端组件、样式、审查（通过 Antigravity CLI `agy` 调用 Gemini） |
| image-worker | 自定义 Agent | 配图、图标、插画、占位图（通过 Codex 内置图片生成） |

## 编排工具

全部使用 Claude Code 的稳定工具，不依赖实验性的 Team 功能：

| 动作 | 工具 |
|------|------|
| 启动 worker | `Agent`（`subagent_type` 选 worker，`run_in_background: true` 并行） |
| 隔离并行 worker | `Agent` 的 `isolation: "worktree"` |
| 让同一个 worker 接着干（打回修改、追加任务） | `SendMessage`（`to` 填启动时的 `name`） |

Worker 完成后的汇报会自动回到 Lead，不需要 worker 主动发消息。

## 执行流程

### Phase 1: 分析与拆分

1. 分析用户任务，识别子任务类型：
   - 前端/UI → gemini-worker
   - 后端/逻辑/测试 → codex-worker
   - 图片素材 → image-worker
   - 全栈 → 多个 worker 协作
2. 确定依赖关系（独立任务并行，有依赖的串行）
3. 识别项目上下文（工作目录、技术栈、测试命令、当前分支）
4. 决定是否需要 worktree 隔离（见下文「并行隔离」）

### Phase 2: 启动 Worker

```
Agent tool:
  subagent_type: "codex-worker"
  name: "codex-api"            # 唯一名字，后续 SendMessage 用它
  description: "实现用户 API"
  run_in_background: true
  isolation: "worktree"        # 仅在并行修改同一仓库时使用
  prompt: |
    你是 AI Team 的 Codex 工作者。

    项目工作目录: {workdir}
    项目信息: {project_context}
    基准分支: {base_branch}
    是否在独立 worktree 中: {是/否}

    任务: {task_description}
    验收标准: {acceptance}
```

### Phase 3: 交叉审查门禁

每个写代码的产出，在合并/交付前必须经过**另一个模型**审查：

| 作者 | 审查者 | 审查方式 |
|------|--------|----------|
| codex-worker（代码） | gemini-worker | `gemini-run.sh -m plan`（只读） |
| gemini-worker（UI） | codex-worker | `codex-run.sh -r` |
| image-worker（图片） | Lead 自己 | 用 Read 直接查看图片 |

门禁循环（默认最多打回 **2 轮**，用户另有要求时按用户的来）：

```
1. 作者 worker 完成 → 汇报里带 SESSION_ID、修改的文件、(worktree 路径/分支)
2. Lead 启动审查者 worker（审查任务），告诉它：
   - 审查目录（worktree 路径或项目目录）
   - 审查范围：未提交变更 → --uncommitted；已提交到分支 → --base {base_branch}
3. 审查者返回 VERDICT: PASS 或 VERDICT: FAIL + 问题清单
4. FAIL → Lead 筛掉不成立的意见，用 SendMessage 把剩下的问题发回作者 worker，
         要求它用 --resume {SESSION_ID} 续聊修复（保留上下文，不从头重来）
         → 回到第 2 步
5. PASS → 进入 Phase 4
6. 超过轮数仍 FAIL → 停下，把剩余问题和双方意见汇报给用户决定
```

Lead 对审查意见有最终裁决权：审查者明显误判的问题不必打回。

### Phase 4: 整合与交付

- 有 worktree 的：按「并行隔离」里的步骤合并
- 运行测试验证
- 向用户汇报结果（包括每个任务经过了几轮审查）

## 并行隔离（git worktree）

**何时使用**：两个及以上 worker 同时修改同一个 git 仓库（模式 C）。串行任务和只读任务不需要。

**流程**：
1. 启动时给每个写代码的 worker 加 `isolation: "worktree"`，它们各自在独立的 worktree 和分支上工作
2. Worker 在自己的 worktree 里调用 CLI（`-d` 指向 worktree 根目录）
3. Worker 完成后把变更 commit 到自己的分支，汇报 worktree 路径和分支名
4. 交叉审查在该 worktree 里进行（`-r --base {base_branch}`）；修复后追加 commit
5. 全部 PASS 后，Lead 在主工作目录依次合并：
   ```bash
   git merge --no-ff <worker 分支>
   ```
   有冲突时 Lead 自己解决，或者把冲突交给相关 worker 处理
6. 合并完成并测试通过后清理：
   ```bash
   git worktree remove <worktree 路径>
   git branch -d <worker 分支>
   ```

**前提**：项目必须是 git 仓库，且基准分支上没有未提交的改动（否则 worker 看不到这些改动）。有未提交改动时先问用户是否提交。

**项目不是当前会话工作目录时**：`isolation: "worktree"` 只对 Claude Code 当前会话所在的仓库生效。此时由 Lead 手动创建 worktree，启动 worker 时不加 `isolation`，在 prompt 里给出 worktree 路径：
```bash
# 放在项目目录旁边，避免主仓库把它当成未跟踪文件
git -C <项目目录> worktree add ../<项目名>-<任务名> -b ai-team/<任务名>
```

## 上下文传递

当一个 worker 的输出需要传递给另一个 worker 时：

1. **文件路径** - 前序 worker 生成的文件已在工作目录中，后续 worker 可直接读取（worktree 模式下要先合并，或者给出 worktree 路径）
2. **摘要传递** - Team Lead 在 prompt 或 SendMessage 中带上前序输出的关键信息
3. **任务描述** - 在后续任务的 prompt 中写明前序的设计决策和接口定义

## 错误处理

- Worker 失败 → 分析原因，修改 prompt 后用 SendMessage 让它重试
- CLI 超时 → 拆分为更小的子任务，或用 `-t` 加大超时
- 合并冲突 → Team Lead 解决
- 审查轮数用完 → 交给用户决定

## 流水线模式

### 模式 A: UI → 实现（串行）
```
gemini-worker 设计 UI → codex-worker 审查 UI ⇄ 修复 → codex-worker 实现逻辑 → gemini-worker 审查 ⇄ 修复 → 测试
```

### 模式 B: 审查 → 修复（串行）
```
codex-worker 审查代码 → Team Lead 确认 → codex-worker 修复问题 → gemini-worker 复审 ⇄ 修复 → 测试
```

### 模式 C: 多模块并行（worktree 隔离）
```
codex-worker-1 模块 A（worktree A）⇄ 交叉审查 ─┐
codex-worker-2 模块 B（worktree B）⇄ 交叉审查 ─┤→ Team Lead 合并 → 集成测试
gemini-worker  UI    （worktree C）⇄ 交叉审查 ─┘
```

### 配图（可插入任意模式）
```
image-worker 生成素材 → Team Lead 查看图片 ⇄ 续聊修改 → 交给 UI worker 引用
```

流水线 prompt 模板见 `references/pipeline-templates.md`。

# AI Team Skills for Claude Code

将 Gemini CLI 和 Codex CLI 集成为 Claude Code 的两个独立 skill，让 Claude Code 能够：

- 委派 UI 设计任务给 **Gemini Pro**
- 委派代码编写任务给 **Codex (gpt-5.2-codex)**
- 支持**委派模式**（单任务分发）和**流水线模式**（设计 → 实现 → 审查）

## 架构

```
Claude Code (编排者/大脑)
    ├── gemini-agent skill → gemini-cli → UI/前端设计
    └── codex-agent skill  → codex-cli  → 代码编写/实现
```

## Skills

### gemini-agent

Gemini Pro AI 代理 - UI 设计与前端开发专家。

```
/gemini-agent <UI 设计描述>
```

- 包装脚本：`gemini-agent/scripts/gemini-run.sh`
- Prompt 模板：`gemini-agent/references/prompt-templates.md`

### codex-agent

Codex AI 代理 - 代码编写与实现专家。

```
/codex-agent <代码任务描述>
```

- 包装脚本：`codex-agent/scripts/codex-run.sh`
- Prompt 模板：`codex-agent/references/prompt-templates.md`

## 协作模式

### 委派模式（单任务）

Claude Code 分析任务 → 构建 prompt → 调用对应 CLI → 收集结果

### 流水线模式（全栈开发）

1. Claude 分析需求，拆分为设计 + 实现
2. Gemini 设计 UI 代码
3. Claude 审查，构建实现 prompt
4. Codex 实现完整功能代码
5. Claude 审查整合

## 前置要求

- [Gemini CLI](https://github.com/google-gemini/gemini-cli) 已安装并登录
- [Codex CLI](https://github.com/openai/codex) 已安装并配置
- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) 已安装

## 安装

将 `gemini-agent` 和 `codex-agent` 目录复制到你的 Claude Code skills 目录：

```bash
cp -r gemini-agent codex-agent /path/to/your/project/.claude/skills/
```

## License

MIT

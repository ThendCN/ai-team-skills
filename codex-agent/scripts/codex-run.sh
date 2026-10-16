#!/usr/bin/env bash
set -euo pipefail

# codex-run.sh - Codex CLI 包装脚本
# 用于 Claude Code codex-agent skill 调用 Codex

# 常见 bin 路径追加到 PATH 末尾作兜底（追加而非前置，避免盖过用户 PATH 里更新的 codex）
export PATH="$PATH:$HOME/.local/share/pnpm:$HOME/.local/bin:/usr/local/bin:/usr/bin:/bin"

# 默认值
MODEL=""
WORKDIR="."
TIMEOUT=900  # 15分钟，codex 任务通常需要 5-15 分钟
SANDBOX="workspace-write"
OUTPUT_FILE=""
PROMPT_FILE=""
PROMPT_ARGS=""
MODE="exec"  # exec | review
RESUME_ID=""

usage() {
    cat <<'USAGE'
Usage: codex-run.sh [OPTIONS] [prompt...]

Options:
  -m, --model <model>        模型覆盖（默认用 config.toml 配置）
  -d, --dir <directory>      工作目录（默认当前目录）
  -t, --timeout <seconds>    超时时间（默认 900s）
  -s, --sandbox <mode>       沙箱模式: workspace-write(默认) | dangerous | read-only
                             （full-auto 为 workspace-write 的旧别名）
  -o, --output <file>        将最终消息写入文件
  -f, --file <file>          从文件读取 prompt（推荐）
      --resume <session_id>  续聊之前的会话（session id 见上次运行 stderr 的 SESSION_ID）
  -r, --review               使用 codex exec review 模式（代码审查）
      --uncommitted          审查未提交的变更（仅 review 模式）
      --base <branch>        审查相对于指定分支的变更（仅 review 模式）
  -h, --help                 显示帮助

Examples:
  codex-run.sh "实现一个 REST API"
  codex-run.sh -f /tmp/prompt.txt -d ./my-project
  codex-run.sh -f /tmp/prompt.txt -s dangerous -o /tmp/result.txt
  codex-run.sh -r --uncommitted -d ./my-project -o /tmp/review.txt
  codex-run.sh --resume <session_id> -f /tmp/fix.txt -d ./my-project -o /tmp/result.txt
  echo "修复登录 bug" | codex-run.sh
USAGE
    exit 0
}

REVIEW_FLAGS=()

# 解析参数
while [[ $# -gt 0 ]]; do
    case "$1" in
        -m|--model)
            MODEL="$2"; shift 2 ;;
        -d|--dir)
            WORKDIR="$2"; shift 2 ;;
        -t|--timeout)
            TIMEOUT="$2"; shift 2 ;;
        -s|--sandbox)
            SANDBOX="$2"; shift 2 ;;
        -o|--output)
            OUTPUT_FILE="$2"; shift 2 ;;
        -f|--file)
            PROMPT_FILE="$2"; shift 2 ;;
        -r|--review)
            MODE="review"; shift ;;
        --resume)
            RESUME_ID="$2"; shift 2 ;;
        --uncommitted)
            REVIEW_FLAGS+=(--uncommitted); shift ;;
        --base)
            REVIEW_FLAGS+=(--base "$2"); shift 2 ;;
        -h|--help)
            usage ;;
        --)
            shift; PROMPT_ARGS="$*"; break ;;
        -*)
            echo "Error: Unknown option $1" >&2; exit 1 ;;
        *)
            PROMPT_ARGS="$*"; break ;;
    esac
done

# 获取 prompt：文件 > 参数 > stdin（review 模式下 prompt 可选，只能用 -f 或参数）
if [[ -n "$PROMPT_FILE" ]]; then
    if [[ ! -f "$PROMPT_FILE" ]]; then
        echo "Error: Prompt file not found: $PROMPT_FILE" >&2
        exit 1
    fi
    PROMPT=$(cat "$PROMPT_FILE")
elif [[ -n "$PROMPT_ARGS" ]]; then
    PROMPT="$PROMPT_ARGS"
elif [[ "$MODE" == "review" ]]; then
    PROMPT=""  # review 模式下 prompt 可选，不读 stdin（被 agent 调用时 stdin 可能永远不关闭）
elif [[ ! -t 0 ]]; then
    PROMPT=$(cat)
else
    echo "Error: No prompt provided. Use -f, arguments, or pipe stdin." >&2
    exit 1
fi

# 验证工作目录
if [[ ! -d "$WORKDIR" ]]; then
    echo "Error: Working directory not found: $WORKDIR" >&2
    exit 1
fi

# 输出文件转为绝对路径（脚本会 cd 到工作目录执行）
if [[ -n "$OUTPUT_FILE" && "$OUTPUT_FILE" != /* ]]; then
    OUTPUT_FILE="$PWD/$OUTPUT_FILE"
fi

# 验证 codex 可用
if ! command -v codex &>/dev/null; then
    echo "Error: codex CLI not found. Install with: pnpm add -g @openai/codex" >&2
    exit 1
fi

if [[ "$MODE" == "review" && -n "$RESUME_ID" ]]; then
    echo "Error: --resume cannot be used with --review" >&2
    exit 1
fi

# 沙箱模式（用 -c 设置，exec 和 exec resume 通用）
case "$SANDBOX" in
    workspace-write|full-auto)
        SANDBOX_ARGS=(-c 'sandbox_mode="workspace-write"') ;;
    dangerous)
        SANDBOX_ARGS=(--dangerously-bypass-approvals-and-sandbox) ;;
    read-only)
        SANDBOX_ARGS=(-c 'sandbox_mode="read-only"') ;;
    *)
        echo "Error: Invalid sandbox mode: $SANDBOX" >&2
        exit 1 ;;
esac

# 构建 codex 命令
if [[ "$MODE" == "review" ]]; then
    CODEX_ARGS=(exec review ${REVIEW_FLAGS[@]+"${REVIEW_FLAGS[@]}"})
elif [[ -n "$RESUME_ID" ]]; then
    CODEX_ARGS=(exec resume "${SANDBOX_ARGS[@]}")
else
    CODEX_ARGS=(exec "${SANDBOX_ARGS[@]}")
fi

# 模型覆盖
if [[ -n "$MODEL" ]]; then
    CODEX_ARGS+=(-m "$MODEL")
fi

# 默认跳过 git 仓库检查
CODEX_ARGS+=(--skip-git-repo-check)

# 输出文件
if [[ -n "$OUTPUT_FILE" ]]; then
    CODEX_ARGS+=(-o "$OUTPUT_FILE")
fi

if [[ -n "$RESUME_ID" ]]; then
    CODEX_ARGS+=("$RESUME_ID")
fi

# 执行信息
echo "=== Codex Agent Starting ===" >&2
echo "Mode: $MODE | Sandbox: $SANDBOX | Dir: $WORKDIR | Timeout: ${TIMEOUT}s" >&2
if [[ -n "$MODEL" ]]; then
    echo "Model: $MODEL" >&2
fi
if [[ -n "$RESUME_ID" ]]; then
    echo "Resume: $RESUME_ID" >&2
fi
echo "---" >&2

# 执行 codex CLI：prompt 通过 stdin 传递（避免参数长度限制）
run_codex() {
    if [[ -n "$PROMPT" ]]; then
        printf '%s\n' "$PROMPT" | timeout "$TIMEOUT" codex "${CODEX_ARGS[@]}" -
    else
        timeout "$TIMEOUT" codex "${CODEX_ARGS[@]}" </dev/null
    fi
}

# stderr 照常输出，同时留一份用来提取 session id
ERR_LOG=$(mktemp)
trap 'rm -f "$ERR_LOG"' EXIT

cd "$WORKDIR"
set +e
{ run_codex 2>&1 1>&3 | tee "$ERR_LOG" >&2; } 3>&1
EXIT_CODE=${PIPESTATUS[0]}
set -e

SESSION_ID=$(sed -n 's/^session id: //p' "$ERR_LOG" | head -n 1)
if [[ -n "$SESSION_ID" ]]; then
    echo "SESSION_ID: $SESSION_ID" >&2
fi

if [[ $EXIT_CODE -eq 124 ]]; then
    echo "Error: Codex execution timed out after ${TIMEOUT}s" >&2
    exit 124
fi

exit $EXIT_CODE

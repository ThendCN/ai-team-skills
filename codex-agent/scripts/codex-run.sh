#!/usr/bin/env bash
set -euo pipefail

# codex-run.sh - Codex CLI 包装脚本
# 用于 Claude Code codex-agent skill 调用 Codex

# 确保 pnpm 全局 bin 在 PATH 中
export PATH="$HOME/.local/share/pnpm:$HOME/.local/bin:/usr/local/bin:/usr/bin:/bin:$PATH"

# 默认值
MODEL=""
WORKDIR="."
TIMEOUT=900  # 15分钟，codex 任务通常需要 5-15 分钟
SANDBOX="full-auto"
OUTPUT_FILE=""
PROMPT_FILE=""
PROMPT_ARGS=""
MODE="exec"  # exec | review

usage() {
    cat <<'USAGE'
Usage: codex-run.sh [OPTIONS] [prompt...]

Options:
  -m, --model <model>        模型覆盖（默认用 config.toml 配置）
  -d, --dir <directory>      工作目录（默认当前目录）
  -t, --timeout <seconds>    超时时间（默认 900s）
  -s, --sandbox <mode>       沙箱模式: full-auto(默认) | dangerous | read-only
  -o, --output <file>        将最终消息写入文件
  -f, --file <file>          从文件读取 prompt（推荐）
  -r, --review               使用 codex exec review 模式（代码审查）
      --uncommitted          审查未提交的变更（仅 review 模式）
      --base <branch>        审查相对于指定分支的变更（仅 review 模式）
  -h, --help                 显示帮助

Examples:
  codex-run.sh "实现一个 REST API"
  codex-run.sh -f /tmp/prompt.txt -d ./my-project
  codex-run.sh -f /tmp/prompt.txt -s dangerous -o /tmp/result.txt
  codex-run.sh -r --uncommitted -d ./my-project -o /tmp/review.txt
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

# 获取 prompt：文件 > 参数 > stdin（review 模式下 prompt 可选）
if [[ -n "$PROMPT_FILE" ]]; then
    if [[ ! -f "$PROMPT_FILE" ]]; then
        echo "Error: Prompt file not found: $PROMPT_FILE" >&2
        exit 1
    fi
    PROMPT=$(cat "$PROMPT_FILE")
elif [[ -n "$PROMPT_ARGS" ]]; then
    PROMPT="$PROMPT_ARGS"
elif [[ ! -t 0 ]]; then
    PROMPT=$(cat)
elif [[ "$MODE" == "review" ]]; then
    PROMPT=""  # review 模式下 prompt 可选
else
    echo "Error: No prompt provided. Use -f, arguments, or pipe stdin." >&2
    exit 1
fi

# 验证工作目录
if [[ ! -d "$WORKDIR" ]]; then
    echo "Error: Working directory not found: $WORKDIR" >&2
    exit 1
fi

# 验证 codex 可用
if ! command -v codex &>/dev/null; then
    echo "Error: codex CLI not found. Install with: pnpm add -g @openai/codex" >&2
    exit 1
fi

# 构建 codex 命令
CODEX_ARGS=(exec)

if [[ "$MODE" == "review" ]]; then
    # review 子命令
    CODEX_ARGS+=(review)
    CODEX_ARGS+=("${REVIEW_FLAGS[@]}")

    # 模型覆盖
    if [[ -n "$MODEL" ]]; then
        CODEX_ARGS+=(-m "$MODEL")
    fi

    # 默认跳过 git 仓库检查
    CODEX_ARGS+=(--skip-git-repo-check)
else
    # 普通 exec 模式

    # 沙箱模式（使用正确的 codex CLI 参数）
    case "$SANDBOX" in
        full-auto)
            CODEX_ARGS+=(--full-auto) ;;
        dangerous)
            CODEX_ARGS+=(--dangerously-bypass-approvals-and-sandbox) ;;
        read-only)
            CODEX_ARGS+=(-s read-only) ;;
        *)
            echo "Error: Invalid sandbox mode: $SANDBOX" >&2
            exit 1 ;;
    esac

    # 工作目录
    CODEX_ARGS+=(-C "$WORKDIR")

    # 模型覆盖
    if [[ -n "$MODEL" ]]; then
        CODEX_ARGS+=(-m "$MODEL")
    fi

    # 默认跳过 git 仓库检查
    CODEX_ARGS+=(--skip-git-repo-check)

    # 输出文件（仅 exec 模式支持 -o）
    if [[ -n "$OUTPUT_FILE" ]]; then
        CODEX_ARGS+=(-o "$OUTPUT_FILE")
    fi
fi

# 执行信息
echo "=== Codex Agent Starting ===" >&2
echo "Mode: $MODE | Sandbox: $SANDBOX | Dir: $WORKDIR | Timeout: ${TIMEOUT}s" >&2
if [[ -n "$MODEL" ]]; then
    echo "Model: $MODEL" >&2
fi
echo "---" >&2

# 执行 codex CLI
if [[ "$MODE" == "review" ]]; then
    # review 模式：不支持 -C，需要 cd；不支持 -o，用重定向
    cd "$WORKDIR"
    if [[ -n "$OUTPUT_FILE" ]]; then
        if [[ -n "$PROMPT" ]]; then
            timeout "$TIMEOUT" codex "${CODEX_ARGS[@]}" "$PROMPT" > "$OUTPUT_FILE" 2>&1
        else
            timeout "$TIMEOUT" codex "${CODEX_ARGS[@]}" > "$OUTPUT_FILE" 2>&1
        fi
    else
        if [[ -n "$PROMPT" ]]; then
            timeout "$TIMEOUT" codex "${CODEX_ARGS[@]}" "$PROMPT" 2>&1
        else
            timeout "$TIMEOUT" codex "${CODEX_ARGS[@]}" 2>&1
        fi
    fi
    EXIT_CODE=$?
else
    # exec 模式：通过 stdin 传递长 prompt（避免参数长度限制）
    if [[ -n "$PROMPT" ]]; then
        echo "$PROMPT" | timeout "$TIMEOUT" codex "${CODEX_ARGS[@]}" -
        EXIT_CODE=$?
    else
        timeout "$TIMEOUT" codex "${CODEX_ARGS[@]}"
        EXIT_CODE=$?
    fi
fi

if [[ $EXIT_CODE -eq 124 ]]; then
    echo "Error: Codex execution timed out after ${TIMEOUT}s" >&2
    exit 124
fi

exit $EXIT_CODE

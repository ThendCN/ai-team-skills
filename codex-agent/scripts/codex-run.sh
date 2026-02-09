#!/usr/bin/env bash
set -euo pipefail

# codex-run.sh - Codex CLI 包装脚本
# 用于 Claude Code codex-agent skill 调用 Codex (gpt-5.2-codex)

# 默认值
MODEL=""
WORKDIR="."
TIMEOUT=600
SANDBOX="full-auto"
OUTPUT_FILE=""
PROMPT_FILE=""
PROMPT_ARGS=""

usage() {
    cat <<'USAGE'
Usage: codex-run.sh [OPTIONS] [prompt...]

Options:
  -m, --model <model>        模型覆盖（默认用 config.toml 配置）
  -d, --dir <directory>      工作目录（默认当前目录）
  -t, --timeout <seconds>    超时时间（默认 600s）
  -s, --sandbox <mode>       沙箱模式: full-auto(默认) | dangerous | read-only
  -o, --output <file>        将最终消息写入文件
  -f, --file <file>          从文件读取 prompt（推荐）
  -h, --help                 显示帮助

Examples:
  codex-run.sh "实现一个 REST API"
  codex-run.sh -f /tmp/prompt.txt -d ./my-project
  codex-run.sh -f /tmp/prompt.txt -s dangerous -o /tmp/result.txt
  echo "修复登录 bug" | codex-run.sh
USAGE
    exit 0
}

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

# 获取 prompt：文件 > 参数 > stdin
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
else
    echo "Error: No prompt provided. Use -f, arguments, or pipe stdin." >&2
    exit 1
fi

if [[ -z "$PROMPT" ]]; then
    echo "Error: Empty prompt." >&2
    exit 1
fi

# 验证工作目录
if [[ ! -d "$WORKDIR" ]]; then
    echo "Error: Working directory not found: $WORKDIR" >&2
    exit 1
fi

# 构建 codex 命令
CODEX_ARGS=(exec)

# prompt 作为第一个位置参数
CODEX_ARGS+=("$PROMPT")

# 沙箱模式
case "$SANDBOX" in
    full-auto)
        CODEX_ARGS+=(--full-auto) ;;
    dangerous)
        CODEX_ARGS+=(--dangerously-auto-approve) ;;
    read-only)
        CODEX_ARGS+=(--read-only) ;;
    *)
        echo "Error: Invalid sandbox mode: $SANDBOX" >&2
        exit 1 ;;
esac

# 模型覆盖
if [[ -n "$MODEL" ]]; then
    CODEX_ARGS+=(--model "$MODEL")
fi

# 执行 codex CLI
cd "$WORKDIR"
echo "=== Codex Agent Starting ===" >&2
echo "Sandbox: $SANDBOX | Dir: $WORKDIR | Timeout: ${TIMEOUT}s" >&2
if [[ -n "$MODEL" ]]; then
    echo "Model: $MODEL" >&2
fi
echo "---" >&2

if [[ -n "$OUTPUT_FILE" ]]; then
    timeout "$TIMEOUT" codex "${CODEX_ARGS[@]}" 2>&1 | tee "$OUTPUT_FILE"
    EXIT_CODE=${PIPESTATUS[0]}
else
    timeout "$TIMEOUT" codex "${CODEX_ARGS[@]}"
    EXIT_CODE=$?
fi

if [[ $EXIT_CODE -eq 124 ]]; then
    echo "Error: Codex execution timed out after ${TIMEOUT}s" >&2
    exit 124
fi

exit $EXIT_CODE

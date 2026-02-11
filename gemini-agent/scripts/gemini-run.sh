#!/usr/bin/env bash
set -euo pipefail

# gemini-run.sh - Gemini CLI 包装脚本
# 用于 Claude Code gemini-agent skill 调用 Gemini (gemini-3-pro-preview)

# 默认值
MODE="yolo"
WORKDIR="."
TIMEOUT=300
MODEL=""
PROMPT_FILE=""
PROMPT_ARGS=""

usage() {
    cat <<'USAGE'
Usage: gemini-run.sh [OPTIONS] [prompt...]

Options:
  -m, --mode <yolo|prompt>   执行模式（默认 yolo，自动批准所有操作）
  --model <model>            模型覆盖（默认使用 gemini CLI 配置）
  -d, --dir <directory>      工作目录（默认当前目录）
  -t, --timeout <seconds>    超时时间（默认 300s）
  -f, --file <file>          从文件读取 prompt（推荐，避免 shell 转义问题）
  -h, --help                 显示帮助

Examples:
  gemini-run.sh "设计一个登录页面"
  gemini-run.sh -f /tmp/prompt.txt -d ./my-project
  echo "设计一个表单" | gemini-run.sh
USAGE
    exit 0
}

# 解析参数
while [[ $# -gt 0 ]]; do
    case "$1" in
        -m|--mode)
            MODE="$2"; shift 2 ;;
        --model)
            MODEL="$2"; shift 2 ;;
        -d|--dir)
            WORKDIR="$2"; shift 2 ;;
        -t|--timeout)
            TIMEOUT="$2"; shift 2 ;;
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

# 构建 gemini 命令参数
GEMINI_ARGS=()

if [[ -n "$MODEL" ]]; then
    GEMINI_ARGS+=(-m "$MODEL")
fi

if [[ "$MODE" == "yolo" ]]; then
    GEMINI_ARGS+=(-y)
fi

# 将 prompt 写入临时文件以避免 shell 转义问题
TMPFILE=$(mktemp /tmp/gemini-prompt-XXXXXX.txt)
trap 'rm -f "$TMPFILE"' EXIT
echo "$PROMPT" > "$TMPFILE"

# 执行 gemini CLI
cd "$WORKDIR"
echo "=== Gemini Agent Starting ===" >&2
echo "Mode: $MODE | Dir: $WORKDIR | Timeout: ${TIMEOUT}s" >&2
echo "---" >&2

timeout "$TIMEOUT" gemini "${GEMINI_ARGS[@]}" "$(cat "$TMPFILE")"
EXIT_CODE=$?

if [[ $EXIT_CODE -eq 124 ]]; then
    echo "Error: Gemini execution timed out after ${TIMEOUT}s" >&2
    exit 124
fi

exit $EXIT_CODE

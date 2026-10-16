#!/usr/bin/env bash
set -euo pipefail

# gemini-run.sh - Gemini 包装脚本（通过 Antigravity CLI `agy` 调用）
# 用于 Claude Code gemini-agent skill 调用 Gemini
# 注：gemini CLI 已不再支持个人账号登录（IneligibleTierError），改用 agy

# 默认值
MODE="yolo"
WORKDIR="."
TIMEOUT=600
MODEL="gemini-3.8-flash-high"
PROMPT_FILE=""
PROMPT_ARGS=""
OUTPUT_FILE=""
RESUME_ID=""

usage() {
    cat <<'USAGE'
Usage: gemini-run.sh [OPTIONS] [prompt...]

Options:
  -m, --mode <yolo|plan>     执行模式（默认 yolo，自动批准所有操作；plan 为只读，用于审查）
  --model <model>            模型覆盖（默认 gemini-3.8-flash-high；可选值见 `agy models`）
  -d, --dir <directory>      工作目录（默认当前目录）
  -t, --timeout <seconds>    超时时间（默认 600s）
  -f, --file <file>          从文件读取 prompt（推荐，避免 shell 转义问题）
  -o, --output <file>        将最终回复写入文件（默认输出到 stdout）
      --resume <session_id>  续聊之前的会话（session id 见上次运行 stderr 的 SESSION_ID）
  -h, --help                 显示帮助

Examples:
  gemini-run.sh "设计一个登录页面"
  gemini-run.sh -f /tmp/prompt.txt -d ./my-project
  gemini-run.sh -m plan -f /tmp/review-prompt.txt -d ./my-project -o /tmp/review.txt
  gemini-run.sh --resume <session_id> -f /tmp/fix.txt -d ./my-project
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
        -o|--output)
            OUTPUT_FILE="$2"; shift 2 ;;
        --resume)
            RESUME_ID="$2"; shift 2 ;;
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

# 输出文件转为绝对路径（脚本会 cd 到工作目录执行）
if [[ -n "$OUTPUT_FILE" && "$OUTPUT_FILE" != /* ]]; then
    OUTPUT_FILE="$PWD/$OUTPUT_FILE"
fi

# 验证 agy 和 python3 可用
if ! command -v agy &>/dev/null; then
    echo "Error: agy (Antigravity CLI) not found. See https://antigravity.google" >&2
    exit 1
fi
if ! command -v python3 &>/dev/null; then
    echo "Error: python3 not found (needed to parse agy JSON output)" >&2
    exit 1
fi

# 构建 agy 命令参数
# headless 模式下无法弹出权限确认，必须自动批准；plan 模式本身不会修改文件
AGY_ARGS=(--output-format json --dangerously-skip-permissions)

case "$MODE" in
    yolo) ;;
    plan) AGY_ARGS+=(--mode plan) ;;
    *)
        echo "Error: Invalid mode: $MODE (yolo|plan)" >&2
        exit 1 ;;
esac

AGY_ARGS+=(--model "$MODEL")

if [[ -n "$RESUME_ID" ]]; then
    AGY_ARGS+=(--conversation "$RESUME_ID")
fi

RESULT_JSON=$(mktemp)
trap 'rm -f "$RESULT_JSON"' EXIT

# 执行 agy
cd "$WORKDIR"
echo "=== Gemini Agent Starting (agy) ===" >&2
echo "Mode: $MODE | Model: $MODEL | Dir: $WORKDIR | Timeout: ${TIMEOUT}s" >&2
if [[ -n "$RESUME_ID" ]]; then
    echo "Resume: $RESUME_ID" >&2
fi
echo "---" >&2

set +e
timeout "$TIMEOUT" agy "${AGY_ARGS[@]}" -p "$PROMPT" </dev/null >"$RESULT_JSON"
EXIT_CODE=$?
set -e

if [[ $EXIT_CODE -eq 124 ]]; then
    echo "Error: Gemini execution timed out after ${TIMEOUT}s" >&2
    exit 124
fi

# 解析 JSON：回复 → stdout 或输出文件，session id → stderr
set +e
python3 - "$RESULT_JSON" "$OUTPUT_FILE" <<'PY'
import json, sys

raw = open(sys.argv[1], encoding="utf-8").read()
try:
    data = json.loads(raw)
except ValueError:
    sys.stderr.write(raw)
    sys.exit(1)

response = data.get("response", "")
if sys.argv[2]:
    with open(sys.argv[2], "w", encoding="utf-8") as f:
        f.write(response)
else:
    sys.stdout.write(response)

if data.get("conversation_id"):
    sys.stderr.write("SESSION_ID: %s\n" % data["conversation_id"])
if data.get("denied_actions"):
    sys.stderr.write("Warning: denied actions: %s\n" % json.dumps(data["denied_actions"], ensure_ascii=False))
if data.get("status") != "SUCCESS":
    sys.stderr.write("Error: agy status %s\n" % data.get("status"))
    sys.exit(1)
PY
PARSE_CODE=$?
set -e

if [[ $EXIT_CODE -ne 0 ]]; then
    exit $EXIT_CODE
fi
exit $PARSE_CODE

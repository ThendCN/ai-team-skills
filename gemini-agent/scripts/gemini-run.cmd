@echo off
setlocal enabledelayedexpansion

REM gemini-run.cmd - Gemini CLI wrapper (native CMD)
REM Native batch script for Claude Code gemini-agent skill.
REM Streams CLI output directly to parent process (no PowerShell needed).

REM --- Defaults ---
set "MODE=yolo"
set "MODEL="
set "DIR=."
set "TIMEOUT=600"
set "PROMPT_FILE="
set "PROMPT_ARGS="

REM --- Parse arguments ---
:parse_args
if "%~1"=="" goto :args_done

if /i "%~1"=="-m"          ( set "MODE=%~2"& shift & shift & goto :parse_args )
if /i "%~1"=="--mode"      ( set "MODE=%~2"& shift & shift & goto :parse_args )
if /i "%~1"=="--model"     ( set "MODEL=%~2"& shift & shift & goto :parse_args )
if /i "%~1"=="-d"          ( set "DIR=%~2"& shift & shift & goto :parse_args )
if /i "%~1"=="--dir"       ( set "DIR=%~2"& shift & shift & goto :parse_args )
if /i "%~1"=="-t"          ( set "TIMEOUT=%~2"& shift & shift & goto :parse_args )
if /i "%~1"=="--timeout"   ( set "TIMEOUT=%~2"& shift & shift & goto :parse_args )
if /i "%~1"=="-f"          ( set "PROMPT_FILE=%~2"& shift & shift & goto :parse_args )
if /i "%~1"=="--file"      ( set "PROMPT_FILE=%~2"& shift & shift & goto :parse_args )
if /i "%~1"=="-h"          goto :show_help
if /i "%~1"=="--help"      goto :show_help

REM Collect remaining args as prompt
set "PROMPT_ARGS=%*"
goto :args_done

:show_help
echo Usage: gemini-run.cmd [OPTIONS] [prompt...]
echo.
echo Options:
echo   -m, --mode ^<yolo^|prompt^>   Execution mode (default: yolo, auto-approve all)
echo       --model ^<model^>         Override model (default from gemini CLI config)
echo   -d, --dir ^<directory^>       Working directory (default: current)
echo   -t, --timeout ^<seconds^>     Timeout in seconds (default: 1800)
echo   -f, --file ^<file^>           Read prompt from file (recommended)
echo   -h, --help                  Show this help
echo.
echo Examples:
echo   gemini-run.cmd -f %%TEMP%%\prompt.txt -d .\my-project
echo   gemini-run.cmd --model gemini-3-pro-preview "Design a login page"
echo.
echo Note: Use -f file mode for long prompts (CMD has 8191-char limit).
exit /b 0

:args_done

REM --- Validate mode ---
if /i not "%MODE%"=="yolo" if /i not "%MODE%"=="prompt" (
    echo Error: Invalid mode: %MODE%. Must be yolo or prompt. >&2
    exit /b 1
)

REM --- Resolve prompt: file ^> args ^> stdin ---
set "PROMPT="
set "PROMPT_TMPFILE="

if defined PROMPT_FILE (
    if not exist "%PROMPT_FILE%" (
        echo Error: Prompt file not found: %PROMPT_FILE% >&2
        exit /b 1
    )
    REM Read file content into PROMPT variable
    set "PROMPT="
    for /f "usebackq delims=" %%L in ("%PROMPT_FILE%") do (
        if not defined PROMPT (
            set "PROMPT=%%L"
        ) else (
            set "PROMPT=!PROMPT! %%L"
        )
    )
    goto :prompt_ready
)

if defined PROMPT_ARGS (
    set "PROMPT=!PROMPT_ARGS!"
    goto :prompt_ready
)

REM Try reading from stdin (piped input)
set "PROMPT_TMPFILE=%TEMP%\gemini-prompt-%RANDOM%.tmp"
findstr "^" > "!PROMPT_TMPFILE!" 2>nul
for %%A in ("!PROMPT_TMPFILE!") do (
    if %%~zA==0 (
        del "!PROMPT_TMPFILE!" >nul 2>&1
        set "PROMPT_TMPFILE="
    )
)

if defined PROMPT_TMPFILE (
    set "PROMPT="
    for /f "usebackq delims=" %%L in ("!PROMPT_TMPFILE!") do (
        if not defined PROMPT (
            set "PROMPT=%%L"
        ) else (
            set "PROMPT=!PROMPT! %%L"
        )
    )
    del "!PROMPT_TMPFILE!" >nul 2>&1
)

if not defined PROMPT (
    echo Error: No prompt provided. Use -f, arguments, or pipe stdin. >&2
    exit /b 1
)

:prompt_ready

REM --- Validate working directory ---
if not exist "%DIR%\" (
    echo Error: Working directory not found: %DIR% >&2
    exit /b 1
)

REM Resolve to absolute path
pushd "%DIR%" || (
    echo Error: Cannot access directory: %DIR% >&2
    exit /b 1
)
set "RESOLVED_DIR=%CD%"
popd

REM --- Locate gemini CLI ---
where gemini >nul 2>&1 || (
    echo Error: gemini CLI not found. Install with: npm install -g @anthropic-ai/gemini-cli >&2
    exit /b 1
)

REM --- Banner ---
echo === Gemini Agent Starting === >&2
echo Mode: %MODE% ^| Dir: %RESOLVED_DIR% ^| Timeout: %TIMEOUT%s >&2
if defined MODEL echo Model: %MODEL% >&2
echo --- >&2

REM --- Resolve mode flag ---
set "MODE_FLAG="
if /i "%MODE%"=="yolo" set "MODE_FLAG=-y"

REM --- Build optional model flag ---
set "MODEL_FLAG="
if defined MODEL set "MODEL_FLAG=-m !MODEL!"

REM --- Timeout watchdog ---
set "MARKER=%TEMP%\gemini-marker-%RANDOM%.tmp"
echo running > "%MARKER%"
set /a "TIMEOUT_TICKS=%TIMEOUT%+1"
start /b cmd /c "ping -n %TIMEOUT_TICKS% 127.0.0.1 >nul 2>&1 && if exist "%MARKER%" (taskkill /f /im gemini.cmd >nul 2>&1 & taskkill /f /im node.exe >nul 2>&1 & echo Error: Gemini execution timed out after %TIMEOUT%s >&2)"

REM --- Create pipe script to auto-answer interactive prompts ---
REM Gemini may prompt "1. Keep trying / 2. Stop" - we pipe "1" to auto-select
set "PIPE_SCRIPT=%TEMP%\gemini-pipe-%RANDOM%.cmd"
> "!PIPE_SCRIPT!" echo @echo off
if defined PROMPT (
    >> "!PIPE_SCRIPT!" echo echo 1^| gemini !MODEL_FLAG! !MODE_FLAG! "!PROMPT!"
) else (
    >> "!PIPE_SCRIPT!" echo echo 1^| gemini !MODEL_FLAG! !MODE_FLAG!
)

REM --- Execute gemini via pipe script (auto-answers prompts) ---
pushd "%RESOLVED_DIR%"
call "!PIPE_SCRIPT!"
set "EXIT_CODE=!ERRORLEVEL!"
popd

REM --- Cleanup ---
del "%MARKER%" >nul 2>&1
del "!PIPE_SCRIPT!" >nul 2>&1

exit /b %EXIT_CODE%

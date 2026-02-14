@echo off
setlocal enabledelayedexpansion

REM codex-run.cmd - Codex CLI wrapper (native CMD)
REM Native batch script for Claude Code codex-agent skill.
REM Streams CLI output directly to parent process (no PowerShell needed).

REM --- Add pnpm global bin to PATH ---
if defined LOCALAPPDATA (
    if exist "%LOCALAPPDATA%\pnpm" (
        set "PATH=%LOCALAPPDATA%\pnpm;%PATH%"
    )
)

REM --- Defaults ---
set "MODEL="
set "DIR=."
set "TIMEOUT=1800"
REM NOTE: On Windows, --full-auto degrades to sandbox:read-only (no Docker).
REM Default to "dangerous" so codex can actually write files.
set "SANDBOX=dangerous"
set "OUTPUT="
set "PROMPT_FILE="
set "EXEC_MODE=exec"
set "REVIEW_UNCOMMITTED="
set "REVIEW_BASE="
set "PROMPT_ARGS="

REM --- Parse arguments ---
:parse_args
if "%~1"=="" goto :args_done

if /i "%~1"=="-m"          ( set "MODEL=%~2"& shift & shift & goto :parse_args )
if /i "%~1"=="--model"     ( set "MODEL=%~2"& shift & shift & goto :parse_args )
if /i "%~1"=="-d"          ( set "DIR=%~2"& shift & shift & goto :parse_args )
if /i "%~1"=="--dir"       ( set "DIR=%~2"& shift & shift & goto :parse_args )
if /i "%~1"=="-t"          ( set "TIMEOUT=%~2"& shift & shift & goto :parse_args )
if /i "%~1"=="--timeout"   ( set "TIMEOUT=%~2"& shift & shift & goto :parse_args )
if /i "%~1"=="-s"          ( set "SANDBOX=%~2"& shift & shift & goto :parse_args )
if /i "%~1"=="--sandbox"   ( set "SANDBOX=%~2"& shift & shift & goto :parse_args )
if /i "%~1"=="-o"          ( set "OUTPUT=%~2"& shift & shift & goto :parse_args )
if /i "%~1"=="--output"    ( set "OUTPUT=%~2"& shift & shift & goto :parse_args )
if /i "%~1"=="-f"          ( set "PROMPT_FILE=%~2"& shift & shift & goto :parse_args )
if /i "%~1"=="--file"      ( set "PROMPT_FILE=%~2"& shift & shift & goto :parse_args )
if /i "%~1"=="-r"          ( set "EXEC_MODE=review"& shift & goto :parse_args )
if /i "%~1"=="--review"    ( set "EXEC_MODE=review"& shift & goto :parse_args )
if /i "%~1"=="--uncommitted" ( set "REVIEW_UNCOMMITTED=1"& shift & goto :parse_args )
if /i "%~1"=="--base"      ( set "REVIEW_BASE=%~2"& shift & shift & goto :parse_args )
if /i "%~1"=="-h"          goto :show_help
if /i "%~1"=="--help"      goto :show_help

REM Collect remaining args as prompt
set "PROMPT_ARGS=%*"
goto :args_done

:show_help
echo Usage: codex-run.cmd [OPTIONS] [prompt...]
echo.
echo Options:
echo   -m, --model ^<model^>        Override model (default from config.toml)
echo   -d, --dir ^<directory^>      Working directory (default: current)
echo   -t, --timeout ^<seconds^>    Timeout in seconds (default: 1800)
echo   -s, --sandbox ^<mode^>       dangerous (default) ^| full-auto ^| read-only
echo   -o, --output ^<file^>        Tee streamed output into file
echo   -f, --file ^<file^>          Read prompt from file
echo   -r, --review               Use codex exec review mode
echo       --uncommitted          Review uncommitted changes (review mode)
echo       --base ^<branch^>        Review changes against branch (review mode)
echo   -h, --help                 Show this help
echo.
echo Examples:
echo   codex-run.cmd -f %%TEMP%%\prompt.txt -d .\my-project
echo   codex-run.cmd -f %%TEMP%%\prompt.txt -s dangerous -d .\my-project
echo   codex-run.cmd -r --uncommitted -d .\my-project -o %%TEMP%%\review.txt
exit /b 0

:args_done

REM --- Resolve prompt: file ^> args ^> stdin ---
set "PROMPT_TMPFILE="

if defined PROMPT_FILE (
    if not exist "%PROMPT_FILE%" (
        echo Error: Prompt file not found: %PROMPT_FILE% >&2
        exit /b 1
    )
    set "PROMPT_TMPFILE=%PROMPT_FILE%"
    goto :prompt_ready
)

if defined PROMPT_ARGS (
    REM Write prompt args to temp file to avoid CMD 8191-char limit
    set "PROMPT_TMPFILE=%TEMP%\codex-prompt-%RANDOM%.tmp"
    > "!PROMPT_TMPFILE!" echo !PROMPT_ARGS!
    goto :prompt_ready
)

REM Try reading from stdin (piped input)
set "PROMPT_TMPFILE=%TEMP%\codex-prompt-%RANDOM%.tmp"
findstr "^" > "!PROMPT_TMPFILE!" 2>nul
for %%A in ("!PROMPT_TMPFILE!") do (
    if %%~zA==0 (
        del "!PROMPT_TMPFILE!" >nul 2>&1
        set "PROMPT_TMPFILE="
    )
)

if not defined PROMPT_TMPFILE (
    if "%EXEC_MODE%"=="review" (
        REM review mode: prompt is optional
        goto :prompt_ready
    )
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

REM --- Locate codex CLI ---
where codex.cmd >nul 2>&1 && (
    for /f "delims=" %%i in ('where codex.cmd') do set "CODEX_EXE=%%i"
    goto :codex_found
)
where codex >nul 2>&1 && (
    for /f "delims=" %%i in ('where codex') do set "CODEX_EXE=%%i"
    goto :codex_found
)
echo Error: codex CLI not found. Install with: pnpm add -g @openai/codex >&2
exit /b 1

:codex_found

REM --- Banner ---
echo === Codex Agent Starting === >&2
echo Mode: %EXEC_MODE% ^| Sandbox: %SANDBOX% ^| Dir: %RESOLVED_DIR% ^| Timeout: %TIMEOUT%s >&2
if defined MODEL echo Model: %MODEL% >&2
if defined OUTPUT echo Output tee file: %OUTPUT% >&2
echo --- >&2

REM --- Build and execute command ---
REM Strategy: use `call` (proper .cmd chaining) + `<` redirection (no pipe
REM subprocess). Flags are kept as simple strings without embedded quotes
REM to avoid CMD expansion/quoting pitfalls.

if "%EXEC_MODE%"=="review" goto :run_review

REM ===== EXEC MODE =====

REM --- Resolve sandbox flag ---
if "%SANDBOX%"=="full-auto"  goto :sb_fullauto
if "%SANDBOX%"=="dangerous"  goto :sb_dangerous
if "%SANDBOX%"=="read-only"  goto :sb_readonly
echo Error: Invalid sandbox mode: %SANDBOX% >&2
exit /b 1

:sb_fullauto
set "SB_FLAG=--full-auto"
goto :sb_done
:sb_dangerous
set "SB_FLAG=--dangerously-bypass-approvals-and-sandbox"
goto :sb_done
:sb_readonly
set "SB_FLAG=-s read-only"
goto :sb_done
:sb_done

REM --- Timeout watchdog ---
set "MARKER=%TEMP%\codex-marker-%RANDOM%.tmp"
echo running > "%MARKER%"
set /a "TIMEOUT_TICKS=%TIMEOUT%+1"
start /b cmd /c "ping -n %TIMEOUT_TICKS% 127.0.0.1 >nul 2>&1 && if exist "%MARKER%" (taskkill /f /im codex.cmd >nul 2>&1 & taskkill /f /im node.exe >nul 2>&1 & echo Error: Codex execution timed out after %TIMEOUT%s >&2)"

REM --- Build optional flags (no embedded quotes) ---
set "OPT="
if defined MODEL set "OPT=-m !MODEL!"
if defined OUTPUT set "OPT=!OPT! -o !OUTPUT!"

REM --- Execute codex directly ---
REM IMPORTANT: avoid call+redirection inside if() blocks — CMD can mangle
REM redirections inside parenthesized blocks. Use goto branches instead.
if not defined PROMPT_TMPFILE goto :exec_no_stdin
call "!CODEX_EXE!" exec !SB_FLAG! -C "!RESOLVED_DIR!" !OPT! - < "!PROMPT_TMPFILE!"
set "EXIT_CODE=!ERRORLEVEL!"
goto :exec_cleanup

:exec_no_stdin
call "!CODEX_EXE!" exec !SB_FLAG! -C "!RESOLVED_DIR!" !OPT!
set "EXIT_CODE=!ERRORLEVEL!"

:exec_cleanup
del "%MARKER%" >nul 2>&1
if defined PROMPT_ARGS if defined PROMPT_TMPFILE del "!PROMPT_TMPFILE!" >nul 2>&1
goto :finish

REM ===== REVIEW MODE =====
:run_review

REM --- Read prompt from file if provided (review takes prompt as argument) ---
set "REVIEW_PROMPT="
if defined PROMPT_TMPFILE (
    for /f "usebackq delims=" %%L in ("%PROMPT_TMPFILE%") do (
        if not defined REVIEW_PROMPT (
            set "REVIEW_PROMPT=%%L"
        ) else (
            set "REVIEW_PROMPT=!REVIEW_PROMPT! %%L"
        )
    )
)

REM --- Build optional flags ---
set "OPT="
if defined REVIEW_UNCOMMITTED set "OPT=--uncommitted"
if defined REVIEW_BASE set "OPT=!OPT! --base !REVIEW_BASE!"
if defined MODEL set "OPT=!OPT! -m !MODEL!"

REM --- Timeout watchdog ---
set "MARKER=%TEMP%\codex-marker-%RANDOM%.tmp"
echo running > "%MARKER%"
set /a "TIMEOUT_TICKS=%TIMEOUT%+1"
start /b cmd /c "ping -n %TIMEOUT_TICKS% 127.0.0.1 >nul 2>&1 && if exist "%MARKER%" (taskkill /f /im codex.cmd >nul 2>&1 & taskkill /f /im node.exe >nul 2>&1 & echo Error: Codex execution timed out after %TIMEOUT%s >&2)"

REM --- Execute review (must cd first, review doesn't support -C) ---
pushd "%RESOLVED_DIR%"
if not defined OUTPUT goto :review_no_output
if not defined REVIEW_PROMPT goto :review_output_noprompt
call "!CODEX_EXE!" exec review !OPT! "!REVIEW_PROMPT!" > "!OUTPUT!" 2>&1
goto :review_done
:review_output_noprompt
call "!CODEX_EXE!" exec review !OPT! > "!OUTPUT!" 2>&1
goto :review_done
:review_no_output
if not defined REVIEW_PROMPT goto :review_plain
call "!CODEX_EXE!" exec review !OPT! "!REVIEW_PROMPT!" 2>&1
goto :review_done
:review_plain
call "!CODEX_EXE!" exec review !OPT! 2>&1
:review_done
set "EXIT_CODE=!ERRORLEVEL!"
popd

REM --- Cleanup ---
del "%MARKER%" >nul 2>&1
if defined PROMPT_ARGS if defined PROMPT_TMPFILE del "!PROMPT_TMPFILE!" >nul 2>&1

:finish
exit /b %EXIT_CODE%

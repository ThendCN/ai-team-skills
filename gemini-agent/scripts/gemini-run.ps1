#Requires -Version 5.1
<#
.SYNOPSIS
    Gemini CLI 包装脚本 (Windows PowerShell)
.DESCRIPTION
    用于 Claude Code gemini-agent skill 调用 Gemini (gemini-3-pro-preview)
    这是 gemini-run.sh 的 Windows 等效脚本
.EXAMPLE
    .\gemini-run.ps1 "设计一个登录页面"
    .\gemini-run.ps1 -File C:\tmp\prompt.txt -Dir .\my-project
#>

param(
    [Alias("m")]
    [ValidateSet("yolo", "prompt")]
    [string]$Mode = "yolo",

    [string]$Model = "",

    [Alias("d")]
    [string]$Dir = ".",

    [Alias("t")]
    [int]$Timeout = 300,

    [Alias("f")]
    [string]$File = "",

    [Alias("h")]
    [switch]$Help,

    [Parameter(ValueFromRemainingArguments)]
    [string[]]$PromptArgs
)

$ErrorActionPreference = "Stop"

if ($Help) {
    @"
Usage: gemini-run.ps1 [OPTIONS] [prompt...]

Options:
  -Mode <yolo|prompt>      执行模式（默认 yolo，自动批准所有操作）
  -Model <model>           模型覆盖（默认使用 gemini CLI 配置）
  -Dir <directory>         工作目录（默认当前目录）
  -Timeout <seconds>       超时时间（默认 300s）
  -File <file>             从文件读取 prompt（推荐，避免转义问题）
  -Help                    显示帮助

Examples:
  .\gemini-run.ps1 "设计一个登录页面"
  .\gemini-run.ps1 -File C:\tmp\prompt.txt -Dir .\my-project
"@
    exit 0
}

# --- 获取 prompt：文件 > 参数 > stdin ---
$Prompt = ""
if ($File) {
    if (-not (Test-Path $File)) {
        Write-Error "Error: Prompt file not found: $File"
        exit 1
    }
    $Prompt = Get-Content -Path $File -Raw -Encoding UTF8
}
elseif ($PromptArgs -and $PromptArgs.Count -gt 0) {
    $Prompt = $PromptArgs -join " "
}
elseif ([System.Console]::IsInputRedirected) {
    $Prompt = [System.Console]::In.ReadToEnd()
}
else {
    Write-Error "Error: No prompt provided. Use -File, arguments, or pipe stdin."
    exit 1
}

if ([string]::IsNullOrWhiteSpace($Prompt)) {
    Write-Error "Error: Empty prompt."
    exit 1
}

# --- 验证工作目录 ---
if (-not (Test-Path $Dir -PathType Container)) {
    Write-Error "Error: Working directory not found: $Dir"
    exit 1
}

# --- 构建 gemini 命令参数 ---
$geminiArgs = @()

if ($Model) {
    $geminiArgs += "-m", $Model
}

if ($Mode -eq "yolo") {
    $geminiArgs += "-y"
}

# 将 prompt 写入临时文件以避免转义问题
$tmpFile = Join-Path ([System.IO.Path]::GetTempPath()) "gemini-prompt-$(Get-Random).txt"
try {
    [System.IO.File]::WriteAllText($tmpFile, $Prompt, [System.Text.Encoding]::UTF8)

    $geminiArgs += (Get-Content $tmpFile -Raw -Encoding UTF8)

    # 执行 gemini CLI
    Push-Location $Dir
    Write-Host "=== Gemini Agent Starting ===" -ForegroundColor Cyan
    Write-Host "Mode: $Mode | Dir: $Dir | Timeout: ${Timeout}s" -ForegroundColor DarkGray
    Write-Host "---" -ForegroundColor DarkGray

    $process = Start-Process -FilePath "gemini" -ArgumentList $geminiArgs -NoNewWindow -PassThru
    $completed = $process.WaitForExit($Timeout * 1000)

    if (-not $completed) {
        $process.Kill()
        Write-Error "Error: Gemini execution timed out after ${Timeout}s"
        exit 124
    }

    exit $process.ExitCode
}
finally {
    Pop-Location
    if (Test-Path $tmpFile) { Remove-Item $tmpFile -Force }
}

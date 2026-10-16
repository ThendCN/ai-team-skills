#Requires -Version 5.1
<#
.SYNOPSIS
    Gemini 包装脚本 (Windows PowerShell)，通过 Antigravity CLI (agy) 调用
.DESCRIPTION
    用于 Claude Code gemini-agent skill 调用 Gemini
    这是 gemini-run.sh 的 Windows 等效脚本
    注：gemini CLI 已不再支持个人账号登录（IneligibleTierError），改用 agy
.EXAMPLE
    .\gemini-run.ps1 "设计一个登录页面"
    .\gemini-run.ps1 -File C:\tmp\prompt.txt -Dir .\my-project
    .\gemini-run.ps1 -Mode plan -File C:\tmp\review.txt -Dir .\my-project -Output C:\tmp\result.txt
    .\gemini-run.ps1 -Resume <session_id> -File C:\tmp\fix.txt -Dir .\my-project
#>

param(
    [Alias("m")]
    [ValidateSet("yolo", "plan")]
    [string]$Mode = "yolo",

    [string]$Model = "gemini-3.8-flash-high",

    [Alias("d")]
    [string]$Dir = ".",

    [Alias("t")]
    [int]$Timeout = 600,

    [Alias("f")]
    [string]$File = "",

    [Alias("o")]
    [string]$Output = "",

    [string]$Resume = "",

    [Alias("h")]
    [switch]$Help,

    [Parameter(ValueFromRemainingArguments)]
    [string[]]$PromptArgs
)

$ErrorActionPreference = "Stop"

function Join-CommandArguments {
    param([string[]]$Arguments)
    $escaped = foreach ($arg in $Arguments) {
        if ($null -eq $arg) {
            '""'
        }
        elseif ($arg -match '[\s"`"]') {
            '"' + ($arg -replace '([\\"])', '\$1') + '"'
        }
        else {
            $arg
        }
    }
    return ($escaped -join ' ')
}

if ($Help) {
    @"
Usage: gemini-run.ps1 [OPTIONS] [prompt...]

Options:
  -Mode <yolo|plan>        执行模式（默认 yolo，自动批准所有操作；plan 为只读，用于审查）
  -Model <model>           模型覆盖（默认 gemini-3.8-flash-high；可选值见 agy models）
  -Dir <directory>         工作目录（默认当前目录）
  -Timeout <seconds>       超时时间（默认 600s）
  -File <file>             从文件读取 prompt（推荐，避免转义问题）
  -Output <file>           将最终回复写入文件（默认输出到 stdout）
  -Resume <session_id>     续聊之前的会话（session id 见上次运行 stderr 的 SESSION_ID）
  -Help                    显示帮助

Examples:
  .\gemini-run.ps1 "设计一个登录页面"
  .\gemini-run.ps1 -File C:\tmp\prompt.txt -Dir .\my-project
  .\gemini-run.ps1 -Mode plan -File C:\tmp\review.txt -Dir .\my-project -Output C:\tmp\result.txt
  .\gemini-run.ps1 -Resume <session_id> -File C:\tmp\fix.txt -Dir .\my-project
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

# --- 输出文件转为绝对路径（脚本会切换到工作目录执行）---
if ($Output) {
    $Output = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Output)
}

# --- 验证 agy 可用 ---
if (-not (Get-Command "agy" -ErrorAction SilentlyContinue)) {
    Write-Error "Error: agy (Antigravity CLI) not found. See https://antigravity.google"
    exit 1
}

# --- 构建 agy 命令参数 ---
# headless 模式下无法弹出权限确认，必须自动批准；plan 模式本身不会修改文件
$agyArgs = @("--output-format", "json", "--dangerously-skip-permissions")
if ($Mode -eq "plan") { $agyArgs += "--mode", "plan" }
$agyArgs += "--model", $Model
if ($Resume) { $agyArgs += "--conversation", $Resume }
$agyArgs += "-p", $Prompt

# 执行 agy（使用 System.Diagnostics.Process 实现超时控制）
Push-Location $Dir
try {
    Write-Host "=== Gemini Agent Starting (agy) ===" -ForegroundColor Cyan
    Write-Host "Mode: $Mode | Model: $Model | Dir: $Dir | Timeout: ${Timeout}s" -ForegroundColor DarkGray
    if ($Resume) { Write-Host "Resume: $Resume" -ForegroundColor DarkGray }
    Write-Host "---" -ForegroundColor DarkGray

    $proc = New-Object System.Diagnostics.Process
    $argString = Join-CommandArguments -Arguments $agyArgs

    # npm/pnpm 在 Windows 上生成 .ps1 包装脚本，Process.Start() 无法直接执行
    $cmd = Get-Command "agy" -ErrorAction Stop
    $cmdPath = $cmd.Source
    if ($cmdPath -match '\.ps1$') {
        $cmdVersion = $cmdPath -replace '\.ps1$', '.cmd'
        if (Test-Path $cmdVersion) {
            $proc.StartInfo.FileName = $cmdVersion
            $proc.StartInfo.Arguments = $argString
        }
        else {
            $psExe = if (Get-Command "pwsh" -ErrorAction SilentlyContinue) {
                (Get-Command "pwsh").Source
            } else { "powershell.exe" }
            $proc.StartInfo.FileName = $psExe
            $proc.StartInfo.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$cmdPath`" $argString"
        }
    }
    else {
        $proc.StartInfo.FileName = $cmdPath
        $proc.StartInfo.Arguments = $argString
    }
    $proc.StartInfo.UseShellExecute = $false
    $proc.StartInfo.RedirectStandardInput = $true
    $proc.StartInfo.RedirectStandardOutput = $true
    $proc.StartInfo.StandardOutputEncoding = [System.Text.Encoding]::UTF8
    $proc.Start() | Out-Null
    $proc.StandardInput.Close()
    $stdoutTask = $proc.StandardOutput.ReadToEndAsync()

    $completed = $proc.WaitForExit($Timeout * 1000)
    if (-not $completed) {
        $proc.Kill()
        [Console]::Error.WriteLine("Error: Gemini execution timed out after ${Timeout}s")
        exit 124
    }

    # 解析 JSON：回复 → stdout 或输出文件，session id → stderr
    $raw = $stdoutTask.Result
    try {
        $data = $raw | ConvertFrom-Json
    }
    catch {
        [Console]::Error.Write($raw)
        exit 1
    }

    $response = [string]$data.response
    if ($Output) {
        [System.IO.File]::WriteAllText($Output, $response, (New-Object System.Text.UTF8Encoding($false)))
    }
    else {
        [Console]::Out.Write($response)
    }

    if ($data.conversation_id) {
        [Console]::Error.WriteLine("SESSION_ID: $($data.conversation_id)")
    }
    if ($data.denied_actions) {
        [Console]::Error.WriteLine("Warning: denied actions: $($data.denied_actions | ConvertTo-Json -Compress)")
    }
    if ($data.status -ne "SUCCESS") {
        [Console]::Error.WriteLine("Error: agy status $($data.status)")
        exit 1
    }

    exit $proc.ExitCode
}
finally {
    Pop-Location
}

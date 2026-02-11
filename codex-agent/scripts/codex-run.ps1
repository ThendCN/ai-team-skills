#Requires -Version 5.1
<#
.SYNOPSIS
    Codex CLI 包装脚本 (Windows PowerShell)
.DESCRIPTION
    用于 Claude Code codex-agent skill 调用 Codex
    这是 codex-run.sh 的 Windows 等效脚本
.EXAMPLE
    .\codex-run.ps1 "实现一个 REST API"
    .\codex-run.ps1 -File C:\tmp\prompt.txt -Dir .\my-project
    .\codex-run.ps1 -Review -Uncommitted -Dir .\my-project -Output C:\tmp\review.txt
#>

param(
    [Alias("m")]
    [string]$Model = "",

    [Alias("d")]
    [string]$Dir = ".",

    [Alias("t")]
    [int]$Timeout = 600,

    [Alias("s")]
    [ValidateSet("full-auto", "dangerous", "read-only")]
    [string]$Sandbox = "full-auto",

    [Alias("o")]
    [string]$Output = "",

    [Alias("f")]
    [string]$File = "",

    [Alias("r")]
    [switch]$Review,

    [switch]$Uncommitted,

    [string]$Base = "",

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

# 确保常见 bin 路径在 PATH 中（Windows pnpm 全局路径）
if ($env:LOCALAPPDATA) {
    $pnpmGlobal = Join-Path $env:LOCALAPPDATA "pnpm"
    if (Test-Path $pnpmGlobal) {
        $env:PATH = "$pnpmGlobal;$env:PATH"
    }
}

if ($Help) {
    @"
Usage: codex-run.ps1 [OPTIONS] [prompt...]

Options:
  -Model <model>           模型覆盖（默认用 config.toml 配置）
  -Dir <directory>         工作目录（默认当前目录）
  -Timeout <seconds>       超时时间（默认 600s）
  -Sandbox <mode>          沙箱模式: full-auto(默认) | dangerous | read-only
  -Output <file>           将最终消息写入文件
  -File <file>             从文件读取 prompt（推荐）
  -Review                  使用 codex exec review 模式（代码审查）
  -Uncommitted             审查未提交的变更（仅 review 模式）
  -Base <branch>           审查相对于指定分支的变更（仅 review 模式）
  -Help                    显示帮助

Examples:
  .\codex-run.ps1 "实现一个 REST API"
  .\codex-run.ps1 -File C:\tmp\prompt.txt -Dir .\my-project
  .\codex-run.ps1 -File C:\tmp\prompt.txt -Sandbox dangerous -Output C:\tmp\result.txt
  .\codex-run.ps1 -Review -Uncommitted -Dir .\my-project -Output C:\tmp\review.txt
"@
    exit 0
}

$ExecMode = if ($Review) { "review" } else { "exec" }

# --- 获取 prompt ---
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
elseif ($ExecMode -eq "review") {
    $Prompt = ""
}
else {
    Write-Error "Error: No prompt provided. Use -File, arguments, or pipe stdin."
    exit 1
}

# --- 验证工作目录 ---
if (-not (Test-Path $Dir -PathType Container)) {
    Write-Error "Error: Working directory not found: $Dir"
    exit 1
}

# --- 验证 codex 可用 ---
if (-not (Get-Command "codex" -ErrorAction SilentlyContinue)) {
    Write-Error "Error: codex CLI not found. Install with: pnpm add -g @openai/codex"
    exit 1
}

# --- 构建 codex 命令 ---
$codexArgs = @("exec")

if ($ExecMode -eq "review") {
    $codexArgs += "review"
    if ($Uncommitted) { $codexArgs += "--uncommitted" }
    if ($Base) { $codexArgs += "--base", $Base }
    if ($Model) { $codexArgs += "-m", $Model }
}
else {
    switch ($Sandbox) {
        "full-auto"  { $codexArgs += "--full-auto" }
        "dangerous"  { $codexArgs += "--dangerously-bypass-approvals-and-sandbox" }
        "read-only"  { $codexArgs += "-s", "read-only" }
    }
    $codexArgs += "-C", (Resolve-Path $Dir).Path
    if ($Model) { $codexArgs += "-m", $Model }
    if ($Output) { $codexArgs += "-o", $Output }
}

# --- 执行信息 ---
Write-Host "=== Codex Agent Starting ===" -ForegroundColor Cyan
Write-Host "Mode: $ExecMode | Sandbox: $Sandbox | Dir: $Dir | Timeout: ${Timeout}s" -ForegroundColor DarkGray
if ($Model) { Write-Host "Model: $Model" -ForegroundColor DarkGray }
Write-Host "---" -ForegroundColor DarkGray

# --- 辅助函数：使用 System.Diagnostics.Process 执行 codex ---
function Invoke-Codex {
    param(
        [string[]]$Arguments,
        [string]$StdinFile = "",
        [string]$OutputFile = "",
        [int]$TimeoutSec = 600
    )
    $proc = New-Object System.Diagnostics.Process
    $proc.StartInfo.FileName = "codex"
    $proc.StartInfo.Arguments = Join-CommandArguments -Arguments $Arguments
    $proc.StartInfo.UseShellExecute = $false

    if ($StdinFile) {
        $proc.StartInfo.RedirectStandardInput = $true
    }
    if ($OutputFile) {
        $proc.StartInfo.RedirectStandardOutput = $true
        $proc.StartInfo.RedirectStandardError = $true
    }

    $proc.Start() | Out-Null

    if ($StdinFile) {
        $proc.StandardInput.Write([System.IO.File]::ReadAllText($StdinFile, [System.Text.Encoding]::UTF8))
        $proc.StandardInput.Close()
    }
    if ($OutputFile) {
        # 读取 stdout/stderr 到文件（避免死锁需异步读取）
        $stdoutTask = $proc.StandardOutput.ReadToEndAsync()
        $stderrTask = $proc.StandardError.ReadToEndAsync()
    }

    $completed = $proc.WaitForExit($TimeoutSec * 1000)
    if (-not $completed) {
        $proc.Kill()
        Write-Error "Error: Codex execution timed out after ${TimeoutSec}s"
        exit 124
    }

    if ($OutputFile) {
        $content = $stdoutTask.Result
        if ($stderrTask.Result) { $content += "`n" + $stderrTask.Result }
        [System.IO.File]::WriteAllText($OutputFile, $content, [System.Text.Encoding]::UTF8)
    }

    exit $proc.ExitCode
}

# --- 执行 codex CLI ---
if ($ExecMode -eq "review") {
    Push-Location $Dir
    try {
        if ($Prompt) { $codexArgs += $Prompt }
        Invoke-Codex -Arguments $codexArgs -OutputFile $Output -TimeoutSec $Timeout
    }
    finally { Pop-Location }
}
else {
    if ($Prompt) {
        $tmpFile = Join-Path ([System.IO.Path]::GetTempPath()) "codex-prompt-$(Get-Random).txt"
        try {
            [System.IO.File]::WriteAllText($tmpFile, $Prompt, [System.Text.Encoding]::UTF8)
            $codexArgs += "-"
            Invoke-Codex -Arguments $codexArgs -StdinFile $tmpFile -TimeoutSec $Timeout
        }
        finally {
            if (Test-Path $tmpFile) { Remove-Item $tmpFile -Force }
        }
    }
    else {
        Invoke-Codex -Arguments $codexArgs -TimeoutSec $Timeout
    }
}

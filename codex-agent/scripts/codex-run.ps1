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
    .\codex-run.ps1 -Resume <session_id> -File C:\tmp\fix.txt -Dir .\my-project
#>

param(
    [Alias("m")]
    [string]$Model = "",

    [Alias("d")]
    [string]$Dir = ".",

    [Alias("t")]
    [int]$Timeout = 900,

    [Alias("s")]
    [ValidateSet("workspace-write", "full-auto", "dangerous", "read-only")]
    [string]$Sandbox = "workspace-write",

    [Alias("o")]
    [string]$Output = "",

    [Alias("f")]
    [string]$File = "",

    [Alias("r")]
    [switch]$Review,

    [string]$Resume = "",

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

# Windows pnpm 全局路径追加到 PATH 末尾作兜底（追加而非前置，避免盖过用户 PATH 里更新的 codex）
if ($env:LOCALAPPDATA) {
    $pnpmGlobal = Join-Path $env:LOCALAPPDATA "pnpm"
    if (Test-Path $pnpmGlobal) {
        $env:PATH = "$env:PATH;$pnpmGlobal"
    }
}

if ($Help) {
    @"
Usage: codex-run.ps1 [OPTIONS] [prompt...]

Options:
  -Model <model>           模型覆盖（默认用 config.toml 配置）
  -Dir <directory>         工作目录（默认当前目录）
  -Timeout <seconds>       超时时间（默认 900s）
  -Sandbox <mode>          沙箱模式: workspace-write(默认) | dangerous | read-only
                           （full-auto 为 workspace-write 的旧别名）
  -Output <file>           将最终消息写入文件
  -File <file>             从文件读取 prompt（推荐）
  -Resume <session_id>     续聊之前的会话（session id 见上次运行 stderr 的 SESSION_ID）
  -Review                  使用 codex exec review 模式（代码审查）
  -Uncommitted             审查未提交的变更（仅 review 模式）
  -Base <branch>           审查相对于指定分支的变更（仅 review 模式）
  -Help                    显示帮助

Examples:
  .\codex-run.ps1 "实现一个 REST API"
  .\codex-run.ps1 -File C:\tmp\prompt.txt -Dir .\my-project
  .\codex-run.ps1 -File C:\tmp\prompt.txt -Sandbox dangerous -Output C:\tmp\result.txt
  .\codex-run.ps1 -Review -Uncommitted -Dir .\my-project -Output C:\tmp\review.txt
  .\codex-run.ps1 -Resume <session_id> -File C:\tmp\fix.txt -Dir .\my-project
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
elseif ($ExecMode -eq "review") {
    $Prompt = ""
}
elseif ([System.Console]::IsInputRedirected) {
    $Prompt = [System.Console]::In.ReadToEnd()
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

# --- 输出文件转为绝对路径（脚本会切换到工作目录执行）---
if ($Output) {
    $Output = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Output)
}

if ($Review -and $Resume) {
    Write-Error "Error: -Resume cannot be used with -Review"
    exit 1
}

# --- 验证 codex 可用 ---
if (-not (Get-Command "codex" -ErrorAction SilentlyContinue)) {
    Write-Error "Error: codex CLI not found. Install with: pnpm add -g @openai/codex"
    exit 1
}

# --- 沙箱模式（用 -c 设置，exec 和 exec resume 通用）---
switch ($Sandbox) {
    "dangerous" { $sandboxArgs = @("--dangerously-bypass-approvals-and-sandbox") }
    "read-only" { $sandboxArgs = @("-c", "sandbox_mode=read-only") }
    default     { $sandboxArgs = @("-c", "sandbox_mode=workspace-write") }
}

# --- 构建 codex 命令 ---
if ($ExecMode -eq "review") {
    $codexArgs = @("exec", "review")
    if ($Uncommitted) { $codexArgs += "--uncommitted" }
    if ($Base) { $codexArgs += "--base", $Base }
}
elseif ($Resume) {
    $codexArgs = @("exec", "resume") + $sandboxArgs
}
else {
    $codexArgs = @("exec") + $sandboxArgs
}
if ($Model) { $codexArgs += "-m", $Model }
$codexArgs += "--skip-git-repo-check"
if ($Output) { $codexArgs += "-o", $Output }
if ($Resume) { $codexArgs += $Resume }

# --- 执行信息 ---
Write-Host "=== Codex Agent Starting ===" -ForegroundColor Cyan
Write-Host "Mode: $ExecMode | Sandbox: $Sandbox | Dir: $Dir | Timeout: ${Timeout}s" -ForegroundColor DarkGray
if ($Model) { Write-Host "Model: $Model" -ForegroundColor DarkGray }
if ($Resume) { Write-Host "Resume: $Resume" -ForegroundColor DarkGray }
Write-Host "---" -ForegroundColor DarkGray

# --- 辅助函数：解析 CLI 可执行文件路径（处理 npm/pnpm 的 .ps1 包装问题）---
function Resolve-CliStartInfo {
    param(
        [System.Diagnostics.ProcessStartInfo]$StartInfo,
        [string]$CommandName,
        [string]$ArgumentString
    )
    $cmd = Get-Command $CommandName -ErrorAction Stop
    $cmdPath = $cmd.Source

    # npm/pnpm 在 Windows 上生成 .ps1 包装脚本，Process.Start() 无法直接执行
    # 优先使用同目录下的 .cmd 版本，否则通过 powershell.exe 间接执行
    if ($cmdPath -match '\.ps1$') {
        $cmdVersion = $cmdPath -replace '\.ps1$', '.cmd'
        if (Test-Path $cmdVersion) {
            $StartInfo.FileName = $cmdVersion
            $StartInfo.Arguments = $ArgumentString
        }
        else {
            $psExe = if (Get-Command "pwsh" -ErrorAction SilentlyContinue) {
                (Get-Command "pwsh").Source
            } else { "powershell.exe" }
            $StartInfo.FileName = $psExe
            $StartInfo.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$cmdPath`" $ArgumentString"
        }
    }
    else {
        $StartInfo.FileName = $cmdPath
        $StartInfo.Arguments = $ArgumentString
    }
}

# --- 辅助函数：使用 System.Diagnostics.Process 执行 codex ---
# stdout 直接透传；stderr 捕获后转发，并从中提取 session id
function Invoke-Codex {
    param(
        [string[]]$Arguments,
        [string]$StdinFile = "",
        [int]$TimeoutSec = 900
    )
    $proc = New-Object System.Diagnostics.Process
    $argString = Join-CommandArguments -Arguments $Arguments
    Resolve-CliStartInfo -StartInfo $proc.StartInfo -CommandName "codex" -ArgumentString $argString
    $proc.StartInfo.UseShellExecute = $false
    $proc.StartInfo.RedirectStandardInput = $true
    $proc.StartInfo.RedirectStandardError = $true
    $proc.StartInfo.StandardErrorEncoding = [System.Text.Encoding]::UTF8

    $proc.Start() | Out-Null
    $stderrTask = $proc.StandardError.ReadToEndAsync()

    if ($StdinFile) {
        $proc.StandardInput.Write([System.IO.File]::ReadAllText($StdinFile, [System.Text.Encoding]::UTF8))
    }
    $proc.StandardInput.Close()

    $completed = $proc.WaitForExit($TimeoutSec * 1000)
    if (-not $completed) {
        $proc.Kill()
        [Console]::Error.WriteLine("Error: Codex execution timed out after ${TimeoutSec}s")
        exit 124
    }

    $stderr = $stderrTask.Result
    [Console]::Error.Write($stderr)
    if ($stderr -match '(?m)^session id: (\S+)') {
        [Console]::Error.WriteLine("SESSION_ID: $($Matches[1])")
    }

    exit $proc.ExitCode
}

# --- 执行 codex CLI：prompt 通过 stdin 传递（避免参数长度限制）---
$tmpFile = ""
Push-Location $Dir
try {
    if ($Prompt) {
        $tmpFile = Join-Path ([System.IO.Path]::GetTempPath()) "codex-prompt-$(Get-Random).txt"
        [System.IO.File]::WriteAllText($tmpFile, $Prompt, [System.Text.Encoding]::UTF8)
        $codexArgs += "-"
        Invoke-Codex -Arguments $codexArgs -StdinFile $tmpFile -TimeoutSec $Timeout
    }
    else {
        Invoke-Codex -Arguments $codexArgs -TimeoutSec $Timeout
    }
}
finally {
    Pop-Location
    if ($tmpFile -and (Test-Path $tmpFile)) { Remove-Item $tmpFile -Force }
}

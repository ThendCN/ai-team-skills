#Requires -Version 5.1
<#
.SYNOPSIS
    Codex CLI wrapper (Windows PowerShell)
.DESCRIPTION
    Runs Codex CLI for local AI agent workflows with realtime streaming output.
    For `cmd.exe`, prefer `codex-run.cmd` in the same directory.
#>

[CmdletBinding(PositionalBinding = $false)]
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
  -Model <model>           Override model (default from config.toml)
  -Dir <directory>         Working directory (default: current)
  -Timeout <seconds>       Timeout in seconds (default: 600)
  -Sandbox <mode>          full-auto (default) | dangerous | read-only
  -Output <file>           Tee streamed output into file
  -File <file>             Read prompt from file
  -Review                  Use `codex exec review` mode
  -Uncommitted             Review uncommitted changes (review mode)
  -Base <branch>           Review changes against branch (review mode)
  -Help                    Show this help

Examples:
  powershell -File .\codex-run.ps1 "Implement a REST API"
  .\codex-run.ps1 -File C:\tmp\prompt.txt -Dir .\my-project
  .\codex-run.ps1 -Sandbox dangerous "Fix login bug"
  .\codex-run.ps1 -Review -Uncommitted -Dir .\my-project

CMD recommended entry:
  codex-run.cmd "Build a polished Snake web game"
"@
    exit 0
}

$ExecMode = if ($Review) { "review" } else { "exec" }

$Prompt = ""
if ($File) {
    if (-not (Test-Path $File -PathType Leaf)) {
        Write-Error "Error: Prompt file not found: $File"
        exit 1
    }
    $Prompt = Get-Content -Path $File -Raw -Encoding UTF8
}
elseif ($PromptArgs -and $PromptArgs.Count -gt 0) {
    $Prompt = $PromptArgs -join " "
}
elseif ([Console]::IsInputRedirected) {
    $Prompt = [Console]::In.ReadToEnd()
}
elseif ($ExecMode -eq "review") {
    $Prompt = ""
}
else {
    Write-Error "Error: No prompt provided. Use -File, prompt arguments, or pipe stdin."
    exit 1
}

if (-not (Test-Path $Dir -PathType Container)) {
    Write-Error "Error: Working directory not found: $Dir"
    exit 1
}

$codexCmd = Get-Command "codex.cmd" -ErrorAction SilentlyContinue
if (-not $codexCmd) {
    $codexCmd = Get-Command "codex" -ErrorAction SilentlyContinue
}

if (-not $codexCmd) {
    Write-Error "Error: codex CLI not found. Install with: pnpm add -g @openai/codex"
    exit 1
}

$codexExecutable = $codexCmd.Source
if (-not $codexExecutable) {
    $codexExecutable = $codexCmd.Definition
}

$resolvedDir = (Resolve-Path $Dir).Path
$codexArgs = @("exec")
$stdinText = ""

if ($ExecMode -eq "review") {
    $codexArgs += "review"
    if ($Uncommitted) { $codexArgs += "--uncommitted" }
    if ($Base) { $codexArgs += "--base", $Base }
    if ($Model) { $codexArgs += "-m", $Model }
    if ($Prompt) { $codexArgs += $Prompt }
}
else {
    switch ($Sandbox) {
        "full-auto" { $codexArgs += "--full-auto" }
        "dangerous" { $codexArgs += "--dangerously-bypass-approvals-and-sandbox" }
        "read-only" { $codexArgs += "-s", "read-only" }
    }

    $codexArgs += "-C", $resolvedDir
    if ($Model) { $codexArgs += "-m", $Model }
    if ($Output) { $codexArgs += "-o", $Output }

    if ($Prompt) {
        $codexArgs += "-"
        $stdinText = $Prompt
    }
}

Write-Host "=== Codex Agent Starting ===" -ForegroundColor Cyan
Write-Host "Mode: $ExecMode | Sandbox: $Sandbox | Dir: $resolvedDir | Timeout: ${Timeout}s" -ForegroundColor DarkGray
if ($Model) { Write-Host "Model: $Model" -ForegroundColor DarkGray }
if ($Output) { Write-Host "Output tee file: $Output" -ForegroundColor DarkGray }
Write-Host "---" -ForegroundColor DarkGray

function ConvertTo-CommandLine {
    param([string[]]$Items)

    $quoted = @()
    foreach ($item in $Items) {
        if ($null -eq $item) {
            continue
        }

        if ($item -eq "") {
            $quoted += '""'
            continue
        }

        if ($item -match '[\s"]') {
            $escaped = $item -replace '(\\*)"', '$1$1\\"'
            $escaped = $escaped -replace '(\\+)$', '$1$1'
            $quoted += ('"' + $escaped + '"')
        }
        else {
            $quoted += $item
        }
    }

    return ($quoted -join ' ')
}

function Invoke-Codex {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Executable,

        [Parameter(Mandatory = $true)]
        [string[]]$Arguments,

        [string]$StdinText = "",

        [string]$OutputFile = "",

        [int]$TimeoutSec = 600
    )

    $proc = New-Object System.Diagnostics.Process
    $proc.StartInfo.FileName = $Executable
    $proc.StartInfo.Arguments = ConvertTo-CommandLine -Items $Arguments
    $proc.StartInfo.UseShellExecute = $false
    $proc.StartInfo.RedirectStandardInput = [string]::IsNullOrEmpty($StdinText) -eq $false
    $proc.StartInfo.RedirectStandardOutput = $true
    $proc.StartInfo.RedirectStandardError = $true
    $proc.StartInfo.StandardOutputEncoding = [System.Text.Encoding]::UTF8
    $proc.StartInfo.StandardErrorEncoding = [System.Text.Encoding]::UTF8

    $writer = $null
    if ($OutputFile) {
        $outputParent = Split-Path -Parent $OutputFile
        if ($outputParent -and -not (Test-Path $outputParent)) {
            New-Item -Path $outputParent -ItemType Directory -Force | Out-Null
        }
        $writer = [System.IO.StreamWriter]::new($OutputFile, $false, [System.Text.Encoding]::UTF8)
        $writer.AutoFlush = $true
    }

    $stdoutDone = New-Object System.Threading.AutoResetEvent($false)
    $stderrDone = New-Object System.Threading.AutoResetEvent($false)

    $stdoutHandler = [System.Diagnostics.DataReceivedEventHandler]{
        param($sender, $eventArgs)
        if ($null -eq $eventArgs.Data) {
            [void]$stdoutDone.Set()
            return
        }

        [Console]::Out.WriteLine($eventArgs.Data)
        if ($writer) {
            $writer.WriteLine($eventArgs.Data)
        }
    }

    $stderrHandler = [System.Diagnostics.DataReceivedEventHandler]{
        param($sender, $eventArgs)
        if ($null -eq $eventArgs.Data) {
            [void]$stderrDone.Set()
            return
        }

        [Console]::Error.WriteLine($eventArgs.Data)
        if ($writer) {
            $writer.WriteLine($eventArgs.Data)
        }
    }

    $proc.add_OutputDataReceived($stdoutHandler)
    $proc.add_ErrorDataReceived($stderrHandler)

    try {
        [void]$proc.Start()

        $proc.BeginOutputReadLine()
        $proc.BeginErrorReadLine()

        if ($proc.StartInfo.RedirectStandardInput) {
            $proc.StandardInput.Write($StdinText)
            $proc.StandardInput.Close()
        }

        $timeoutMs = [Math]::Max($TimeoutSec, 1) * 1000
        if (-not $proc.WaitForExit($timeoutMs)) {
            try {
                $proc.Kill($true)
            }
            catch {
                $proc.Kill()
            }
            throw "Error: Codex execution timed out after ${TimeoutSec}s"
        }

        [void]$stdoutDone.WaitOne(3000)
        [void]$stderrDone.WaitOne(3000)

        return $proc.ExitCode
    }
    finally {
        $proc.remove_OutputDataReceived($stdoutHandler)
        $proc.remove_ErrorDataReceived($stderrHandler)

        if ($writer) { $writer.Dispose() }
        $stdoutDone.Dispose()
        $stderrDone.Dispose()
        $proc.Dispose()
    }
}

$exitCode = 0

if ($ExecMode -eq "review") {
    Push-Location $resolvedDir
    try {
        $exitCode = Invoke-Codex -Executable $codexExecutable -Arguments $codexArgs -OutputFile $Output -TimeoutSec $Timeout
    }
    finally {
        Pop-Location
    }
}
else {
    $exitCode = Invoke-Codex -Executable $codexExecutable -Arguments $codexArgs -StdinText $stdinText -OutputFile $Output -TimeoutSec $Timeout
}

exit $exitCode

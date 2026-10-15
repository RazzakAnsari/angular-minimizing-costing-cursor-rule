# minimize-cursor-cost-rule installer for Windows PowerShell 5.1+ and PowerShell 7+
# Author: Abdul Razzak (github.com/RazzakAnsari) - MIT licensed
#
# Remote (from your Angular project root):
#   irm https://raw.githubusercontent.com/RazzakAnsari/minimize-cursor-cost-rule/main/install.ps1 | iex
# Remote with switches:
#   & ([scriptblock]::Create((irm https://raw.githubusercontent.com/RazzakAnsari/minimize-cursor-cost-rule/main/install.ps1))) -DryRun
# Local (from a clone):
#   & <clone>\install.ps1 -Target . -DryRun
#
# Settings can also come from environment variables (handy with | iex):
#   MCCR_TARGET, MCCR_RULES, MCCR_TOOL, MCCR_DRYRUN=1, MCCR_FORCE=1, MCCR_INDEXIGNORE=1
#
# What it does: copies rule files into the target folder. It never overwrites
# a file unless -Force, never runs npm / ng / git, and never edits source code.

param(
    [string]$Target,
    [string]$Rules,
    [string]$Tool,
    [switch]$IndexIgnore,
    [switch]$DryRun,
    [switch]$Force
)

function Invoke-MccrInstall {
    param(
        [string]$Target, [string]$Rules, [string]$Tool,
        [bool]$IndexIgnore, [bool]$DryRun, [bool]$Force, [string]$ScriptDir
    )
    $ErrorActionPreference = 'Stop'
    $zipUrl = 'https://github.com/RazzakAnsari/minimize-cursor-cost-rule/archive/refs/heads/main.zip'
    $alwaysOn = @('guardrails', 'response-style', 'tool-budget', 'project-context')

    if (-not $Target) { $Target = (Get-Location).Path }
    if (-not $Rules)  { $Rules = 'all' }
    if (-not $Tool)   { $Tool = 'cursor' }
    if ($Tool -notin @('cursor', 'agents', 'claude', 'all')) {
        Write-Host "minimize-cursor-cost-rule: unknown tool '$Tool' (use cursor, agents, claude or all)." -ForegroundColor Red
        return
    }
    if (-not (Test-Path -LiteralPath $Target -PathType Container)) {
        Write-Host "minimize-cursor-cost-rule: target folder not found: $Target" -ForegroundColor Red
        return
    }
    $Target = (Resolve-Path -LiteralPath $Target).Path

    if (-not (Test-Path -LiteralPath (Join-Path $Target 'angular.json'))) {
        if ($Force) {
            Write-Host "Warning: no angular.json in $Target - continuing because Force is set." -ForegroundColor Yellow
        } else {
            Write-Host "minimize-cursor-cost-rule: no angular.json in $Target." -ForegroundColor Yellow
            Write-Host 'Run this from your Angular project root, or use -Force / MCCR_FORCE=1.' -ForegroundColor Yellow
            return
        }
    }

    $tempDir = $null
    try {
        # Use the kit next to the script when there is one; otherwise download it.
        $kit = $null
        if ($ScriptDir -and (Test-Path -LiteralPath (Join-Path $ScriptDir 'kit/.cursor/rules'))) {
            $kit = Join-Path $ScriptDir 'kit'
            Write-Host "Using local kit: $kit"
        } else {
            $tempDir = Join-Path ([IO.Path]::GetTempPath()) ('mccr-' + [guid]::NewGuid().ToString('N'))
            New-Item -ItemType Directory -Path $tempDir | Out-Null
            $zip = Join-Path $tempDir 'kit.zip'
            Write-Host "Downloading $zipUrl"
            try { [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12 } catch { }
            $oldProgress = $ProgressPreference
            $ProgressPreference = 'SilentlyContinue'
            try {
                Invoke-WebRequest -Uri $zipUrl -OutFile $zip -UseBasicParsing
                Expand-Archive -LiteralPath $zip -DestinationPath $tempDir -Force
            } finally { $ProgressPreference = $oldProgress }
            $root = Get-ChildItem -LiteralPath $tempDir -Directory | Select-Object -First 1
            if (-not $root) { throw 'Downloaded archive was empty.' }
            $kit = Join-Path $root.FullName 'kit'
        }
        if ((Resolve-Path -LiteralPath $kit).Path.StartsWith($Target + [IO.Path]::DirectorySeparatorChar) -or
            (Resolve-Path -LiteralPath $kit).Path -eq $Target) {
            throw 'Target is the kit itself. Run this from your Angular project root.'
        }

        $ruleDir = Join-Path $kit '.cursor/rules'
        $available = @(Get-ChildItem -LiteralPath $ruleDir -Filter '*.mdc' | ForEach-Object { $_.BaseName })
        if ($Rules -eq 'all') {
            $chosen = $available
        } else {
            $asked = @($Rules.Split(',') | ForEach-Object { $_.Trim() } | Where-Object { $_ })
            $bad = @($asked | Where-Object { $_ -notin $available })
            if ($bad.Count) { throw "Unknown rule(s): $($bad -join ', '). Available: $($available -join ', ')" }
            $chosen = @($alwaysOn + $asked) | Select-Object -Unique
        }

        $tag = if ($DryRun) { '  (dry run - nothing is written)' } else { '' }
        Write-Host "minimize-cursor-cost-rule by Abdul Razzak -> $Target  [tool=$Tool rules=$Rules]$tag"

        $stats = @{ new = 0; replaced = 0; kept = 0 }
        $place = {
            param([string]$From, [string]$Rel)
            $to = Join-Path $Target $Rel
            $there = Test-Path -LiteralPath $to
            if ($there -and -not $Force) {
                Write-Host "  keep     $Rel (already there)"
                $stats.kept++
                return
            }
            $word = if ($there) { 'replace' } else { 'new' }
            if ($DryRun) {
                Write-Host "  would $word $Rel"
            } else {
                $dir = Split-Path -Parent $to
                if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
                Copy-Item -LiteralPath $From -Destination $to -Force
                Write-Host ("  {0,-8} {1}" -f $word, $Rel)
            }
            if ($there) { $stats.replaced++ } else { $stats.new++ }
        }

        if ($Tool -in @('cursor', 'all')) {
            foreach ($r in $chosen) { & $place (Join-Path $ruleDir "$r.mdc") ".cursor/rules/$r.mdc" }
            if ($IndexIgnore) { & $place (Join-Path $kit 'cursorindexingignore.txt') '.cursorindexingignore' }
        }
        if ($Tool -in @('agents', 'all')) { & $place (Join-Path $kit 'AGENTS.md') 'AGENTS.md' }
        if ($Tool -in @('claude', 'all')) { & $place (Join-Path $kit 'CLAUDE.md') 'CLAUDE.md' }
        & $place (Join-Path $kit 'PROMPTS.md') 'PROMPTS.md'

        Write-Host ''
        Write-Host ("Done. new: {0}  replaced: {1}  kept: {2}" -f $stats.new, $stats.replaced, $stats.kept)
        if (-not $DryRun -and $stats.new -gt 0) {
            Write-Host 'Next: fill in .cursor/rules/project-context.mdc, then start a new Cursor chat.'
        }
    } catch {
        Write-Host "minimize-cursor-cost-rule: $($_.Exception.Message)" -ForegroundColor Red
    } finally {
        if ($tempDir -and (Test-Path -LiteralPath $tempDir)) { Remove-Item -LiteralPath $tempDir -Recurse -Force }
    }
}

$mccrOn = { param($v) $v -in @('1', 'true', 'yes') }
Invoke-MccrInstall `
    -Target $(if ($Target) { $Target } else { $env:MCCR_TARGET }) `
    -Rules $(if ($Rules) { $Rules } else { $env:MCCR_RULES }) `
    -Tool $(if ($Tool) { $Tool } else { $env:MCCR_TOOL }) `
    -IndexIgnore ([bool]$IndexIgnore -or (& $mccrOn $env:MCCR_INDEXIGNORE)) `
    -DryRun ([bool]$DryRun -or (& $mccrOn $env:MCCR_DRYRUN)) `
    -Force ([bool]$Force -or (& $mccrOn $env:MCCR_FORCE)) `
    -ScriptDir $PSScriptRoot
Remove-Item -Path function:Invoke-MccrInstall -ErrorAction SilentlyContinue
Remove-Variable -Name mccrOn -ErrorAction SilentlyContinue

# angular-minimizing-costing-cursor-rule installer for Windows PowerShell 5.1+ and PowerShell 7+
# Author: Abdul Razzak (github.com/RazzakAnsari) - MIT licensed
#
# One project (run from its root):
#   irm https://raw.githubusercontent.com/RazzakAnsari/angular-minimizing-costing-cursor-rule/main/install.ps1 | iex
# Every Angular project under the current folder, in one go:
#   $env:MCCR_ALL='1'; irm https://raw.githubusercontent.com/RazzakAnsari/angular-minimizing-costing-cursor-rule/main/install.ps1 | iex; Remove-Item Env:MCCR_ALL
# Where is it installed?
#   $env:MCCR_STATUS='1'; irm https://raw.githubusercontent.com/RazzakAnsari/angular-minimizing-costing-cursor-rule/main/install.ps1 | iex; Remove-Item Env:MCCR_STATUS
# With switches:
#   & ([scriptblock]::Create((irm https://raw.githubusercontent.com/RazzakAnsari/angular-minimizing-costing-cursor-rule/main/install.ps1))) -All -Root C:\code -DryRun
# Local (from a clone):
#   & <clone>\install.ps1 -Target . -DryRun
#
# Switch          Environment variable
#   -Target DIR     MCCR_TARGET       one project (default: current folder)
#   -All            MCCR_ALL=1        every folder with angular.json under -Root
#   -Root DIR       MCCR_ROOT         where -All / -Status look (default: current folder)
#   -Depth N        MCCR_DEPTH        how deep -All / -Status look (default 6)
#   -Status         MCCR_STATUS=1     list projects under -Root and whether the kit is in them
#   -Uninstall      MCCR_UNINSTALL=1  remove only what this installer added (add -All for every project)
#   -Visible        MCCR_VISIBLE=1    do not hide the files from git (use this if you want to commit them)
#   -Rules LIST     MCCR_RULES        all, or a comma list of rule names
#   -Tool NAME      MCCR_TOOL         cursor, agents, claude or all
#   -IndexIgnore    MCCR_INDEXIGNORE=1  also add .cursorindexingignore
#   -DryRun         MCCR_DRYRUN=1     print what would happen, write nothing
#   -Force          MCCR_FORCE=1      replace existing files / allow a folder without angular.json
#
# What it does: copies rule files into Angular projects. Inside a git repo it
# lists those exact files in the repo's .git/info/exclude, so they never show
# up as changes and never end up in a commit. It never edits .gitignore, never
# replaces a file git already tracks, never overwrites anything unless -Force,
# only runs read-only git commands, never runs npm / ng, and never edits source code.

param(
    [string]$Target,
    [string]$Rules,
    [string]$Tool,
    [string]$Root,
    [int]$Depth,
    [switch]$All,
    [switch]$Status,
    [switch]$Uninstall,
    [switch]$Visible,
    [switch]$IndexIgnore,
    [switch]$DryRun,
    [switch]$Force
)

function Invoke-MccrInstall {
    param(
        [string]$Target, [string]$Rules, [string]$Tool, [string]$Root, [int]$Depth,
        [bool]$All, [bool]$Status, [bool]$Uninstall, [bool]$Visible,
        [bool]$IndexIgnore, [bool]$DryRun, [bool]$Force, [string]$ScriptDir
    )
    $ErrorActionPreference = 'Stop'
    $Name = 'angular-minimizing-costing-cursor-rule'
    $Version = '2.0.0'
    $zipUrl = "https://github.com/RazzakAnsari/$Name/archive/refs/heads/main.zip"
    $alwaysOn = @('guardrails', 'response-style', 'tool-budget', 'project-context')
    $knownRules = @('guardrails', 'ng-app-structure', 'ng-components', 'ng-i18n', 'ng-rxjs', 'ng-services', 'ng-signals',
        'ng-specs', 'ng-styles', 'ng-templates', 'project-context', 'response-style', 'tool-budget', 'ts-style')
    $markerRel = '.cursor/rules/.mccr-installed'
    $skipDirs = @('node_modules', 'dist', 'bin', 'obj', 'out', 'coverage')
    $sep = [IO.Path]::DirectorySeparatorChar
    $hasGit = [bool](Get-Command git -CommandType Application -ErrorAction SilentlyContinue)
    $utf8 = New-Object System.Text.UTF8Encoding($false)

    function Say([string]$Text, [string]$Color) {
        if ($Color) { Write-Host $Text -ForegroundColor $Color } else { Write-Host $Text }
    }
    function Get-Full([string]$Path) {
        if ($sep -eq '\') { $Path = $Path.Replace('/', '\') }
        $full = [IO.Path]::GetFullPath($Path)
        if ($full.Length -gt 3) { $full = $full.TrimEnd($sep) }
        $full
    }
    function Resolve-Dir([string]$Path) {
        if (-not (Test-Path -LiteralPath $Path -PathType Container)) { return $null }
        Get-Full (Resolve-Path -LiteralPath $Path).ProviderPath
    }
    function Invoke-MccrGit([string]$Dir, [string[]]$GitArgs) {
        if (-not $hasGit) { return @{ ok = $false; out = @() } }
        $ErrorActionPreference = 'Continue'
        $out = @(& git -C $Dir -c core.quotepath=off @GitArgs 2>$null)
        @{ ok = ($LASTEXITCODE -eq 0); out = $out }
    }
    function Get-Sha([string]$Path) {
        (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
    }

    # Where is this folder's git repo, its info/exclude file, and the folder's path inside the repo?
    function Get-RepoInfo([string]$Dir) {
        $info = [pscustomobject]@{ IsGit = $false; ViaGit = $false; Exclude = ''; Prefix = ''; Top = '' }
        $r = Invoke-MccrGit $Dir @('rev-parse', '--is-inside-work-tree')
        if ($r.ok -and $r.out.Count -and $r.out[0] -eq 'true') {
            $ex = Invoke-MccrGit $Dir @('rev-parse', '--path-format=absolute', '--git-path', 'info/exclude')
            if ($ex.ok -and $ex.out.Count) { $exPath = [string]$ex.out[0] } else {
                $ex = Invoke-MccrGit $Dir @('rev-parse', '--git-path', 'info/exclude')
                $exPath = [string]$ex.out[0]
                if (-not [IO.Path]::IsPathRooted($exPath)) { $exPath = Join-Path $Dir $exPath }
            }
            $pf = Invoke-MccrGit $Dir @('rev-parse', '--show-prefix')
            $top = Invoke-MccrGit $Dir @('rev-parse', '--show-toplevel')
            $info.IsGit = $true
            $info.ViaGit = $true
            $info.Exclude = Get-Full $exPath
            if ($pf.out.Count) { $info.Prefix = [string]$pf.out[0] }
            $info.Top = if ($top.out.Count) { Get-Full ([string]$top.out[0]) } else { $Dir }
            return $info
        }
        # git is missing or refused this folder: find .git by hand (works for worktrees too)
        $cur = $Dir
        $common = $null
        while ($cur) {
            $dotgit = Join-Path $cur '.git'
            if (Test-Path -LiteralPath $dotgit -PathType Container) { $common = $dotgit; break }
            if (Test-Path -LiteralPath $dotgit -PathType Leaf) {
                $line = [string](Get-Content -LiteralPath $dotgit -TotalCount 1)
                if ($line -match '^gitdir:\s*(.+)$') {
                    $gd = $Matches[1].Trim()
                    if (-not [IO.Path]::IsPathRooted($gd)) { $gd = Join-Path $cur $gd }
                    $common = $gd
                    $cdFile = Join-Path $gd 'commondir'
                    if (Test-Path -LiteralPath $cdFile -PathType Leaf) {
                        $c = ([string](Get-Content -LiteralPath $cdFile -TotalCount 1)).Trim()
                        if (-not [IO.Path]::IsPathRooted($c)) { $c = Join-Path $gd $c }
                        $common = $c
                    }
                    break
                }
            }
            $parent = Split-Path -Parent $cur
            if (-not $parent -or $parent -eq $cur) { $cur = $null } else { $cur = $parent }
        }
        if ($common) {
            $info.IsGit = $true
            $info.Exclude = Get-Full (Join-Path $common 'info/exclude')
            $info.Top = $cur
            if ($Dir.Length -gt $cur.Length) {
                $info.Prefix = $Dir.Substring($cur.Length).TrimStart('\', '/').Replace('\', '/') + '/'
            }
        }
        $info
    }

    function ConvertTo-Pattern([string]$Prefix, [string]$Rel) {
        '/' + (($Prefix + $Rel) -replace '([\[\]\*\?\\])', '\$1')
    }

    # Rewrites this project's marked block in info/exclude. Returns $true when the file changes.
    function Set-ExcludeBlock([string]$Path, [string]$Prefix, [string[]]$Patterns, [bool]$Merge) {
        $open = "# >>> $Name /$Prefix >>>"
        $close = "# <<< $Name /$Prefix <<<"
        $exists = Test-Path -LiteralPath $Path -PathType Leaf
        $old = if ($exists) { [IO.File]::ReadAllText($Path) } else { '' }
        $kept = New-Object System.Collections.Generic.List[string]
        $prev = New-Object System.Collections.Generic.List[string]
        $inside = $false
        foreach ($l in ($old -split "`r?`n")) {
            if (-not $inside -and $l -eq $open) { $inside = $true; continue }
            if ($inside) {
                if ($l -eq $close) { $inside = $false } elseif ($l.Trim()) { $prev.Add($l) }
                continue
            }
            $kept.Add($l)
        }
        while ($kept.Count -and $kept[$kept.Count - 1] -eq '') { $kept.RemoveAt($kept.Count - 1) }
        $want = New-Object System.Collections.Generic.List[string]
        if ($Merge) { foreach ($p in $prev) { if (-not $want.Contains($p)) { $want.Add($p) } } }
        foreach ($p in $Patterns) { if ($p -and -not $want.Contains($p)) { $want.Add($p) } }
        if ($want.Count) { $kept.Add($open); $kept.AddRange($want); $kept.Add($close) }
        $text = if ($kept.Count) { ($kept -join "`n") + "`n" } else { '' }
        if ((-not $exists -and -not $text) -or $text -ceq $old) { return $false }
        if (-not $DryRun) {
            $dir = Split-Path -Parent $Path
            if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
            [IO.File]::WriteAllText($Path, $text, $utf8)
        }
        $true
    }

    function Read-Manifest([string]$Dir) {
        $p = Join-Path $Dir $markerRel
        if (-not (Test-Path -LiteralPath $p -PathType Leaf)) { return $null }
        $m = @{ version = '?'; installed = ''; hidden = ''; files = [ordered]@{} }
        foreach ($l in [IO.File]::ReadAllLines($p)) {
            if ($l -match '^file=(\S+) (.+)$') { $m.files[$Matches[2]] = $Matches[1] }
            elseif ($l -match '^(version|installed|hidden)=(.*)$') { $m[$Matches[1]] = $Matches[2] }
        }
        $m
    }
    function Write-Manifest([string]$Dir, $Files, [bool]$Hidden, $Old) {
        $now = (Get-Date).ToString('yyyy-MM-ddTHH:mm:sszzz')
        $first = if ($Old -and $Old.installed) { $Old.installed } else { $now }
        $lines = @($Name, "version=$Version", "installed=$first", "updated=$now", ('hidden=' + $(if ($Hidden) { 'yes' } else { 'no' })))
        foreach ($k in $Files.Keys) { $lines += "file=$($Files[$k]) $k" }
        $p = Join-Path $Dir $markerRel
        $d = Split-Path -Parent $p
        if (-not (Test-Path -LiteralPath $d)) { New-Item -ItemType Directory -Path $d -Force | Out-Null }
        [IO.File]::WriteAllText($p, (($lines -join "`n") + "`n"), $utf8)
    }

    # Other worktrees of the same repo that still have the kit at the same path (they share info/exclude).
    function Get-OtherInstalls([string]$Dir, $Repo) {
        $wl = Invoke-MccrGit $Dir @('worktree', 'list', '--porcelain')
        if (-not $wl.ok) { return }
        foreach ($l in $wl.out) {
            if ($l -like 'worktree *') {
                $wt = Get-Full $l.Substring(9)
                if ($wt -ne $Repo.Top -and (Test-Path -LiteralPath (Join-Path $wt ($Repo.Prefix + $markerRel)) -PathType Leaf)) { $wt }
            }
        }
    }

    function Find-Projects([string]$From, [int]$MaxDepth) {
        $found = New-Object System.Collections.Generic.List[string]
        $queue = New-Object System.Collections.Generic.Queue[object]
        $queue.Enqueue(@($From, 0))
        while ($queue.Count) {
            $cur = $queue.Dequeue()
            $path = [string]$cur[0]
            $lvl = [int]$cur[1]
            if ([IO.File]::Exists((Join-Path $path 'angular.json'))) { $found.Add($path) }
            if ($lvl -ge $MaxDepth) { continue }
            try { $subs = [IO.Directory]::GetDirectories($path) } catch { continue }
            foreach ($s in $subs) {
                $leaf = [IO.Path]::GetFileName($s)
                if ($leaf.StartsWith('.') -or $skipDirs -contains $leaf) { continue }
                try { if ([IO.File]::GetAttributes($s) -band [IO.FileAttributes]::ReparsePoint) { continue } } catch { continue }
                $queue.Enqueue(@($s, ($lvl + 1)))
            }
        }
        # Git worktrees of the repos found count as projects too, even when they live elsewhere.
        foreach ($p in @($found)) {
            $repo = Get-RepoInfo $p
            if (-not $repo.ViaGit) { continue }
            $wl = Invoke-MccrGit $p @('worktree', 'list', '--porcelain')
            foreach ($l in $wl.out) {
                if ($l -like 'worktree *') {
                    $cand = Get-Full ($l.Substring(9) + '/' + $repo.Prefix)
                    if ([IO.File]::Exists((Join-Path $cand 'angular.json')) -and -not ($found -contains $cand)) { $found.Add($cand) }
                }
            }
        }
        @($found | Sort-Object -Unique)
    }

    function Install-One([string]$Dir, [string]$Kit, [string[]]$Chosen) {
        $row = [pscustomobject]@{ Project = $Dir; Result = ''; New = 0; Replaced = 0; Kept = 0; Tracked = 0; Git = '' }
        $items = New-Object System.Collections.Generic.List[object]
        $ruleDir = Join-Path $Kit '.cursor/rules'
        if ($Tool -in @('cursor', 'all')) {
            foreach ($r in $Chosen) { $items.Add(@((Join-Path $ruleDir "$r.mdc"), ".cursor/rules/$r.mdc")) }
            if ($IndexIgnore) { $items.Add(@((Join-Path $Kit 'cursorindexingignore.txt'), '.cursorindexingignore')) }
        }
        if ($Tool -in @('agents', 'all')) { $items.Add(@((Join-Path $Kit 'AGENTS.md'), 'AGENTS.md')) }
        if ($Tool -in @('claude', 'all')) { $items.Add(@((Join-Path $Kit 'CLAUDE.md'), 'CLAUDE.md')) }
        $items.Add(@((Join-Path $Kit 'PROMPTS.md'), 'PROMPTS.md'))

        $repo = Get-RepoInfo $Dir
        $hide = $repo.IsGit -and -not $Visible
        $rels = @(foreach ($it in $items) { $it[1] })
        $tracked = @()
        if ($repo.IsGit) {
            $t = Invoke-MccrGit $Dir (@('ls-files', '--') + $rels + $markerRel)
            if ($t.ok) { $tracked = $t.out }
        }
        $old = Read-Manifest $Dir
        $owned = [ordered]@{}
        foreach ($it in $items) {
            $from = $it[0]; $rel = $it[1]
            $to = Join-Path $Dir $rel
            $there = Test-Path -LiteralPath $to
            if ($hide -and ($tracked -contains $rel)) {
                Say "  tracked  $rel (git already tracks it - skipped; -Visible -Force replaces it)" Yellow
                $row.Tracked++
                continue
            }
            if ($there -and -not $Force) {
                $prevHash = if ($old) { $old.files[$rel] } else { $null }
                if ($prevHash) { $owned[$rel] = $prevHash; Say "  keep     $rel (already installed)" }
                elseif ((Get-Sha $to) -eq (Get-Sha $from)) { $owned[$rel] = Get-Sha $to; Say "  keep     $rel (same as the kit)" }
                else { Say "  keep     $rel (your own file - left alone)" }
                $row.Kept++
                continue
            }
            $word = if ($there) { 'replace' } else { 'new' }
            if ($DryRun) {
                Say "  would $word $rel"
                $owned[$rel] = Get-Sha $from
            } else {
                $d = Split-Path -Parent $to
                if (-not (Test-Path -LiteralPath $d)) { New-Item -ItemType Directory -Path $d -Force | Out-Null }
                Copy-Item -LiteralPath $from -Destination $to -Force
                $owned[$rel] = Get-Sha $to
                Say ("  {0,-8} {1}" -f $word, $rel)
            }
            if ($there) { $row.Replaced++ } else { $row.New++ }
        }
        # Keep earlier entries (for example AGENTS.md from a previous -Tool all run).
        if ($old) {
            foreach ($k in @($old.files.Keys)) {
                if (-not $owned.Contains($k) -and -not ($tracked -contains $k) -and (Test-Path -LiteralPath (Join-Path $Dir $k) -PathType Leaf)) {
                    $owned[$k] = $old.files[$k]
                }
            }
        }
        $canMark = -not ($hide -and ($tracked -contains $markerRel))
        if ($owned.Count -and $canMark -and -not $DryRun) { Write-Manifest $Dir $owned $hide $old }

        if (-not $repo.IsGit) {
            $row.Git = 'not git'
        } elseif ($hide) {
            $row.Git = 'hidden'
            if ($owned.Count) {
                $pats = @(foreach ($k in $owned.Keys) { ConvertTo-Pattern $repo.Prefix $k })
                if ($canMark) { $pats += ConvertTo-Pattern $repo.Prefix $markerRel }
                $changed = Set-ExcludeBlock $repo.Exclude $repo.Prefix $pats $true
                if ($DryRun) { Say "  would hide $($pats.Count) path(s) from git via $($repo.Exclude)" }
                elseif ($changed) { Say "  hidden   $($pats.Count) path(s) from git via $($repo.Exclude)" }
                else { Say "  hidden   $($pats.Count) path(s) from git (already listed in $($repo.Exclude))" }
            }
        } else {
            $row.Git = 'visible'
            $others = @(Get-OtherInstalls $Dir $repo)
            if ($others.Count) {
                Say "  note: other worktrees of this repo share the hide list ($($others -join ', ')), so these files stay hidden here too" Yellow
                $row.Git = 'hidden (shared)'
            } elseif (Set-ExcludeBlock $repo.Exclude $repo.Prefix @() $false) { Say "  visible  removed the earlier hide block from $($repo.Exclude)" }
        }
        $row.Result = if ($DryRun) { 'dry run' } elseif ($row.New -or $row.Replaced) { 'installed' } else { 'up to date' }
        Say ("  done: new {0}, replaced {1}, kept {2}, tracked-skipped {3}" -f $row.New, $row.Replaced, $row.Kept, $row.Tracked)
        $row
    }

    function Uninstall-One([string]$Dir) {
        $row = [pscustomobject]@{ Project = $Dir; Result = ''; Removed = 0; Kept = 0; Git = '' }
        $m = Read-Manifest $Dir
        if (-not $m) { Say "  nothing to remove (no $markerRel here)"; $row.Result = 'not installed'; return $row }
        $repo = Get-RepoInfo $Dir
        $rels = @($m.files.Keys)
        $tracked = @()
        if ($repo.IsGit -and $rels.Count) {
            $t = Invoke-MccrGit $Dir (@('ls-files', '--') + $rels)
            if ($t.ok) { $tracked = $t.out }
        }
        $left = @()
        foreach ($rel in $rels) {
            $p = Join-Path $Dir $rel
            if (-not (Test-Path -LiteralPath $p -PathType Leaf)) { continue }
            if ($tracked -contains $rel) { Say "  keep     $rel (tracked by git)"; $row.Kept++; continue }
            if (-not $Force -and (Get-Sha $p) -ne $m.files[$rel]) {
                Say "  keep     $rel (changed since install; -Force removes it)" Yellow
                $left += $rel; $row.Kept++
                continue
            }
            if ($DryRun) { Say "  would remove $rel" } else { Remove-Item -LiteralPath $p -Force; Say "  removed  $rel" }
            $row.Removed++
        }
        if ($DryRun) { if (-not $left.Count) { Say "  would remove $markerRel" } }
        elseif ($left.Count) {
            # keep the marker for the files left behind so a later -Uninstall -Force can still remove them
            $keep = [ordered]@{}
            foreach ($k in $left) { $keep[$k] = $m.files[$k] }
            Write-Manifest $Dir $keep $repo.IsGit $m
        } else {
            Remove-Item -LiteralPath (Join-Path $Dir $markerRel) -Force
            foreach ($sub in @('.cursor/rules', '.cursor')) {
                $full = Join-Path $Dir $sub
                if ((Test-Path -LiteralPath $full -PathType Container) -and -not (Get-ChildItem -LiteralPath $full -Force | Select-Object -First 1)) {
                    Remove-Item -LiteralPath $full -Force
                }
            }
        }
        if (-not $repo.IsGit) { $row.Git = 'not git' }
        else {
            $others = @(Get-OtherInstalls $Dir $repo)
            if ($others.Count) {
                Say "  kept the git hide block: the kit is still in $($others -join ', ')"
                $row.Git = 'block kept (worktree)'
            } elseif ($left.Count) {
                $pats = @(foreach ($k in $left) { ConvertTo-Pattern $repo.Prefix $k }) + (ConvertTo-Pattern $repo.Prefix $markerRel)
                [void](Set-ExcludeBlock $repo.Exclude $repo.Prefix $pats $false)
                Say "  still hiding $($left.Count) changed file(s) from git"
                $row.Git = 'still hidden'
            } elseif (Set-ExcludeBlock $repo.Exclude $repo.Prefix @() $false) {
                Say "  $(if ($DryRun) { 'would remove' } else { 'removed' }) the hide block from $($repo.Exclude)"
                $row.Git = 'block removed'
            } else { $row.Git = 'no block' }
        }
        $row.Result = if ($DryRun) { 'dry run' } else { 'removed' }
        $row
    }

    function Get-StatusRow([string]$Dir) {
        $m = Read-Manifest $Dir
        $repo = Get-RepoInfo $Dir
        if ($m) { $present = @($m.files.Keys | Where-Object { Test-Path -LiteralPath (Join-Path $Dir $_) -PathType Leaf }) }
        else { $present = @($knownRules | ForEach-Object { ".cursor/rules/$_.mdc" } | Where-Object { Test-Path -LiteralPath (Join-Path $Dir $_) -PathType Leaf }) }
        $ruleCount = @($present | Where-Object { $_ -like '*.mdc' }).Count
        $installed = if ($m) { 'yes' } elseif ($ruleCount) { 'rule files, no marker' } else { 'no' }
        $git = 'not git'
        if ($repo.IsGit) {
            $files = @($present)
            if ($m) { $files += $markerRel }
            if (-not $files.Count) { $git = '-' }
            elseif (-not $repo.ViaGit) { $git = 'unknown (git unavailable)' }
            else {
                $st = Invoke-MccrGit $Dir (@('status', '--porcelain', '--untracked-files=all', '--') + $files)
                $tr = Invoke-MccrGit $Dir (@('ls-files', '--') + $files)
                if (-not $st.ok) { $git = 'unknown (git failed)' }
                elseif ($st.out.Count) { $git = "VISIBLE ($($st.out.Count) change(s))" }
                elseif ($tr.out.Count -ge $files.Count) { $git = 'committed' }
                elseif ($tr.out.Count) { $git = "hidden ($($tr.out.Count) committed)" }
                else { $git = 'hidden' }
            }
        }
        [pscustomobject]@{ Project = $Dir; Installed = $installed; Rules = $ruleCount; Git = $git; Version = $(if ($m) { $m.version } else { '' }) }
    }

    function Show-Table($Rows) {
        Write-Host (($Rows | Format-Table -AutoSize | Out-String -Width 400).TrimEnd())
    }

    # ---- main ----
    if (-not $Rules) { $Rules = 'all' }
    if (-not $Tool) { $Tool = 'cursor' }
    if ($Depth -le 0) { $Depth = 6 }
    if ($Tool -notin @('cursor', 'agents', 'claude', 'all')) {
        Say "${Name}: unknown tool '$Tool' (use cursor, agents, claude or all)." Red
        return
    }
    $mode = if ($Status) { 'status' } elseif ($Uninstall) { 'uninstall' } else { 'install' }

    if ($All -or $Status) {
        $base = if ($Root) { $Root } elseif ($Target) { $Target } else { (Get-Location).ProviderPath }
        $baseFull = Resolve-Dir $base
        if (-not $baseFull) { Say "${Name}: folder not found: $base" Red; return }
        Say "${Name}: looking for angular.json under $baseFull (depth $Depth)"
        $projects = @(Find-Projects $baseFull $Depth)
        if (-not $projects.Count) { Say "No Angular projects (folders with angular.json) under $baseFull." Yellow; return }
        Say "Found $($projects.Count) Angular project(s)."
    } else {
        $t = if ($Target) { $Target } else { (Get-Location).ProviderPath }
        $tFull = Resolve-Dir $t
        if (-not $tFull) { Say "${Name}: target folder not found: $t" Red; return }
        if ($mode -eq 'install' -and -not (Test-Path -LiteralPath (Join-Path $tFull 'angular.json'))) {
            if ($Force) {
                Say "Warning: no angular.json in $tFull - continuing because Force is set." Yellow
            } else {
                Say "${Name}: no angular.json in $tFull." Yellow
                Say 'Run this from your Angular project root, use -Force / MCCR_FORCE=1,' Yellow
                Say 'or use -All / MCCR_ALL=1 to install into every Angular project under this folder.' Yellow
                return
            }
        }
        $projects = @($tFull)
    }

    if ($mode -eq 'status') {
        $rows = @(foreach ($p in $projects) { Get-StatusRow $p })
        Write-Host ''
        Show-Table $rows
        $n = @($rows | Where-Object { $_.Installed -ne 'no' }).Count
        Write-Host ''
        Say "Installed in $n of $($rows.Count) project(s)."
        return
    }

    $tempDir = $null
    try {
        $kit = $null
        $chosen = @()
        if ($mode -eq 'install') {
            # Use the kit next to the script when there is one; otherwise download it once.
            if ($ScriptDir -and (Test-Path -LiteralPath (Join-Path $ScriptDir 'kit/.cursor/rules'))) {
                $kit = Join-Path $ScriptDir 'kit'
                Say "Using local kit: $kit"
            } else {
                $tempDir = Join-Path ([IO.Path]::GetTempPath()) ('mccr-' + [guid]::NewGuid().ToString('N'))
                New-Item -ItemType Directory -Path $tempDir | Out-Null
                $zip = Join-Path $tempDir 'kit.zip'
                Say "Downloading $zipUrl"
                try { [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12 } catch { }
                $oldProgress = $ProgressPreference
                $ProgressPreference = 'SilentlyContinue'
                try {
                    Invoke-WebRequest -Uri $zipUrl -OutFile $zip -UseBasicParsing
                    Expand-Archive -LiteralPath $zip -DestinationPath $tempDir -Force
                } finally { $ProgressPreference = $oldProgress }
                $top = Get-ChildItem -LiteralPath $tempDir -Directory | Select-Object -First 1
                if (-not $top) { throw 'Downloaded archive was empty.' }
                $kit = Join-Path $top.FullName 'kit'
            }
            $kit = Get-Full $kit
            $available = @(Get-ChildItem -LiteralPath (Join-Path $kit '.cursor/rules') -Filter '*.mdc' | ForEach-Object { $_.BaseName })
            if ($Rules -eq 'all') {
                $chosen = $available
            } else {
                $asked = @($Rules.Split(',') | ForEach-Object { $_.Trim() } | Where-Object { $_ })
                $bad = @($asked | Where-Object { $_ -notin $available })
                if ($bad.Count) { throw "Unknown rule(s): $($bad -join ', '). Available: $($available -join ', ')" }
                $chosen = @($alwaysOn + $asked) | Select-Object -Unique
            }
        }

        $tag = if ($DryRun) { '  (dry run - nothing is written)' } else { '' }
        $vis = if ($Visible) { 'visible to git' } else { 'hidden from git' }
        if ($mode -eq 'install') {
            Say "$Name $Version by Abdul Razzak  [tool=$Tool rules=$Rules, $vis]$tag"
        } else {
            Say "$Name $Version - uninstall$tag"
        }

        $rows = @()
        foreach ($p in $projects) {
            Say ''
            Say "-> $p"
            try {
                if ($mode -eq 'install') {
                    if ($kit -eq $p -or $kit.StartsWith($p + $sep, [StringComparison]::OrdinalIgnoreCase)) {
                        Say '  skipped: this folder holds the kit itself' Yellow
                        $rows += [pscustomobject]@{ Project = $p; Result = 'skipped (kit)'; New = 0; Replaced = 0; Kept = 0; Tracked = 0; Git = '' }
                        continue
                    }
                    $rows += Install-One $p $kit $chosen
                } else {
                    $rows += Uninstall-One $p
                }
            } catch {
                Say "  error: $($_.Exception.Message)" Red
                if ($mode -eq 'install') { $rows += [pscustomobject]@{ Project = $p; Result = 'error'; New = 0; Replaced = 0; Kept = 0; Tracked = 0; Git = '' } }
                else { $rows += [pscustomobject]@{ Project = $p; Result = 'error'; Removed = 0; Kept = 0; Git = '' } }
            }
        }

        Write-Host ''
        if ($All) {
            Show-Table $rows
            Write-Host ''
        }
        if ($mode -eq 'install') {
            $tn = ($rows | Measure-Object -Property New -Sum).Sum
            $tr = ($rows | Measure-Object -Property Replaced -Sum).Sum
            $tk = ($rows | Measure-Object -Property Kept -Sum).Sum
            $tt = ($rows | Measure-Object -Property Tracked -Sum).Sum
            Say ("Done. projects: {0}  new: {1}  replaced: {2}  kept: {3}  tracked-skipped: {4}" -f $rows.Count, $tn, $tr, $tk, $tt)
            if (-not $DryRun -and $tn -gt 0) {
                Say 'Next: fill in .cursor/rules/project-context.mdc, then start a new Cursor chat.'
                if (-not $Visible) { Say 'The files are listed in .git/info/exclude, so git and Source Control will not show them. Check any time with -Status.' }
            }
        } else {
            Say ("Done. projects: {0}  removed: {1}  kept: {2}" -f $rows.Count, ($rows | Measure-Object -Property Removed -Sum).Sum, ($rows | Measure-Object -Property Kept -Sum).Sum)
        }
    } catch {
        Say "${Name}: $($_.Exception.Message)" Red
    } finally {
        if ($tempDir -and (Test-Path -LiteralPath $tempDir)) { Remove-Item -LiteralPath $tempDir -Recurse -Force }
    }
}

$mccrOn = { param($v) $v -in @('1', 'true', 'yes') }
Invoke-MccrInstall `
    -Target $(if ($Target) { $Target } else { $env:MCCR_TARGET }) `
    -Rules $(if ($Rules) { $Rules } else { $env:MCCR_RULES }) `
    -Tool $(if ($Tool) { $Tool } else { $env:MCCR_TOOL }) `
    -Root $(if ($Root) { $Root } else { $env:MCCR_ROOT }) `
    -Depth $(if ($Depth -gt 0) { $Depth } elseif ($env:MCCR_DEPTH -as [int]) { [int]$env:MCCR_DEPTH } else { 0 }) `
    -All ([bool]$All -or (& $mccrOn $env:MCCR_ALL)) `
    -Status ([bool]$Status -or (& $mccrOn $env:MCCR_STATUS)) `
    -Uninstall ([bool]$Uninstall -or (& $mccrOn $env:MCCR_UNINSTALL)) `
    -Visible ([bool]$Visible -or (& $mccrOn $env:MCCR_VISIBLE)) `
    -IndexIgnore ([bool]$IndexIgnore -or (& $mccrOn $env:MCCR_INDEXIGNORE)) `
    -DryRun ([bool]$DryRun -or (& $mccrOn $env:MCCR_DRYRUN)) `
    -Force ([bool]$Force -or (& $mccrOn $env:MCCR_FORCE)) `
    -ScriptDir $PSScriptRoot
Remove-Item -Path function:Invoke-MccrInstall -ErrorAction SilentlyContinue
Remove-Variable -Name mccrOn -ErrorAction SilentlyContinue
$global:LASTEXITCODE = 0

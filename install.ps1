#Requires -Version 5.1
#
# NOTE: keep this file pure ASCII.
# Windows PowerShell 5.1 decodes a BOM-less script using the ANSI codepage, so
# non-ASCII text can swallow a closing quote and break parsing. A UTF-8 BOM
# would also work, but any tool that rewrites the file may drop it, so ASCII is
# the durable answer for an installer that has to run everywhere.
<#
.SYNOPSIS
    Bootstrap this dotfiles repository as the Neovim configuration.

.DESCRIPTION
    Links <repo>\nvim into the Neovim config directory, backing up whatever was
    already there, then restores plugins from lazy-lock.json.

    The config directory is resolved from the environment, never hard-coded:
      Windows : %LOCALAPPDATA%\nvim
      Linux   : $XDG_CONFIG_HOME/nvim   (default ~/.config/nvim)
      macOS   : $XDG_CONFIG_HOME/nvim   (default ~/.config/nvim)

    Windows uses a directory junction, so no Administrator rights are needed.

.PARAMETER DryRun
    Print what would happen and change nothing.

.PARAMETER NoPlugins
    Skip the headless "Lazy restore" plugin installation.

.PARAMETER Update
    Run "git pull --ff-only" before linking. Handy on a second machine.

.PARAMETER Target
    Override the Neovim config directory (mainly for testing).

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\install.ps1

.EXAMPLE
    .\install.ps1 -DryRun

.EXAMPLE
    .\install.ps1 -Update
#>
[CmdletBinding()]
param(
    [switch]$DryRun,
    [switch]$NoPlugins,
    [switch]$Update,
    [string]$Target,
    [string]$EmacsTarget
)

$ErrorActionPreference = 'Stop'

function Write-Step { param([string]$Message) Write-Host "==> $Message" -ForegroundColor Cyan }
function Write-Info { param([string]$Message) Write-Host "    $Message" }
function Write-Ok { param([string]$Message) Write-Host "  ok  $Message" -ForegroundColor Green }
function Write-Warn { param([string]$Message) Write-Host "  !   $Message" -ForegroundColor Yellow }

# --- locate the repository ---------------------------------------------------

if ($PSScriptRoot) {
    $repoRoot = $PSScriptRoot
} else {
    $repoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
}

$sourceNvim = Join-Path $repoRoot 'nvim'
if (-not (Test-Path -LiteralPath (Join-Path $sourceNvim 'init.lua'))) {
    throw 'Could not find nvim/init.lua next to this script. Run install.ps1 from the root of the dotfiles repository.'
}

$sourceEmacs = Join-Path $repoRoot 'emacs'
if (-not (Test-Path -LiteralPath (Join-Path $sourceEmacs 'init.el'))) {
    throw 'Could not find emacs/init.el next to this script. Run install.ps1 from the root of the dotfiles repository.'
}

$onWindows = ($env:OS -eq 'Windows_NT')

# --- resolve the Neovim config directory from the environment ----------------

if (-not $Target) {
    if ($onWindows) {
        if ([string]::IsNullOrWhiteSpace($env:LOCALAPPDATA)) {
            throw '$env:LOCALAPPDATA is not set; pass -Target explicitly.'
        }
        $Target = Join-Path $env:LOCALAPPDATA 'nvim'
    } else {
        $base = $env:XDG_CONFIG_HOME
        if ([string]::IsNullOrWhiteSpace($base)) { $base = Join-Path $HOME '.config' }
        $Target = Join-Path $base 'nvim'
    }
}
$Target = [System.IO.Path]::GetFullPath($Target)

# On Windows the Emacs config directory depends on the environment that
# launches Emacs:
#   HOME set   -> $HOME\.emacs.d        (inherited from Git Bash and friends)
#   HOME unset -> %APPDATA%\.emacs.d    (Start menu / Explorer launch)
# Emacs itself sets HOME to %APPDATA% when it is missing, so both can apply.
# Rather than guessing how Emacs will be started, link both to this repo.
if ($EmacsTarget) {
    $emacsTargets = @([System.IO.Path]::GetFullPath($EmacsTarget))
} else {
    $candidates = @()
    if (-not [string]::IsNullOrWhiteSpace($env:APPDATA)) {
        $candidates += (Join-Path $env:APPDATA '.emacs.d')
    }
    $candidates += (Join-Path $HOME '.emacs.d')
    $emacsTargets = @($candidates |
        ForEach-Object { [System.IO.Path]::GetFullPath($_) } |
        Select-Object -Unique)
}

# --- helpers -----------------------------------------------------------------

# Normalise a path for comparison: strip the Global\ / \??\ / \\?\ prefix that
# Windows gives reparse points, resolve it, drop trailing separators, fold case.
function Resolve-RealPath {
    param([string]$Path)
    if ([string]::IsNullOrWhiteSpace($Path)) { return $null }
    $clean = $Path -replace '^Global\\', '' -replace '^\\\?\?\\', '' -replace '^\\\?\\', ''
    try { $clean = (Resolve-Path -LiteralPath $clean -ErrorAction Stop).ProviderPath } catch { }
    return ([string]$clean).TrimEnd('\', '/').ToLowerInvariant()
}

function Get-LinkTarget {
    param($Item)
    if ($null -eq $Item) { return $null }
    if (-not ($Item.PSObject.Properties.Name -contains 'LinkType')) { return $null }
    if (-not $Item.LinkType) { return $null }
    # @() must wrap the whole pipeline: with a single target the pipeline
    # collapses to a string, and "D:\dir"[0] is the letter 'D', not a path.
    $targets = @($Item.Target | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    if ($targets.Count -eq 0) { return $null }
    # PowerShell 5.1 prefixes a junction's Target with the "Global\" namespace.
    # Without stripping it the path never matches the repo, so the
    # "already linked" check silently fails forever.
    return ([string]$targets[0]) -replace '^Global\\', ''
}

# Backup names must be unique: two runs inside the same second would otherwise
# collide and Move-Item would fail.
function New-BackupName {
    param([string]$Path)
    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $name = "$Path.bak-$stamp"
    $n = 0
    while (Test-Path -LiteralPath $name) {
        $n++
        $name = "$Path.bak-$stamp-$n"
    }
    return $name
}

# --- banner ------------------------------------------------------------------

Write-Step "dotfiles : $repoRoot"
Write-Step "nvim dir : $Target"
foreach ($t in $emacsTargets) { Write-Step "emacs dir: $t" }
if ($DryRun) { Write-Warn 'dry run: nothing will be changed' }

# --- optional git pull -------------------------------------------------------

if ($Update) {
    if (Test-Path -LiteralPath (Join-Path $repoRoot '.git')) {
        if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
            Write-Warn 'git is not on PATH; -Update ignored'
        } else {
            Write-Step 'git pull --ff-only'
            if ($DryRun) {
                Write-Info 'skipped (dry run)'
            } else {
                # nvim/ is the live config dir and lazy.nvim rewrites
                # lazy-lock.json in place. Any local drift makes the worktree
                # dirty and git pull --ff-only refuses it. The repo's lock wins,
                # so drop local drift before pulling.
                & git -C $repoRoot checkout -- nvim/lazy-lock.json 2>$null | Out-Null
                & git -C $repoRoot pull --ff-only
                if ($LASTEXITCODE -ne 0) { throw 'git pull failed; run `git -C <repo> status` and retry.' }
                Write-Ok 'repository up to date'
            }
        }
    } else {
        Write-Warn 'not a git checkout; -Update ignored'
    }
}

# --- link a config directory into place --------------------------------------

function Install-Link {
    param(
        [string]$Source,
        [string]$Target,
        [string]$Label
    )

    $existing = Get-Item -LiteralPath $Target -Force -ErrorAction SilentlyContinue
    $linkTarget = Get-LinkTarget $existing
    $alreadyLinked = ($null -ne $linkTarget) -and
                     ((Resolve-RealPath $linkTarget) -eq (Resolve-RealPath $Source))

    if ($alreadyLinked) {
        Write-Ok "$Label already links to $Source"
        return
    }

    if ($null -ne $existing) {
        if ($existing.LinkType) {
            # A link holds no content of its own, so backing it up is pointless
            # and can fail when its target is gone. Just remove it:
            # Directory.Delete drops the reparse point only.
            if ($DryRun) {
                Write-Info "would remove stale $Label $Target"
            } else {
                try {
                    [System.IO.Directory]::Delete($Target, $false)
                } catch {
                    Remove-Item -LiteralPath $Target -Force -ErrorAction Stop
                }
                Write-Ok "stale $Label removed: $Target"
            }
        } else {
            $backup = New-BackupName $Target
            if ($DryRun) {
                Write-Info "would move existing $Label $Target -> $backup"
            } else {
                Move-Item -LiteralPath $Target -Destination $backup
                Write-Ok "existing $Label backed up to $backup"
            }
        }
    }

    $parent = Split-Path -Parent $Target
    if ($parent -and -not (Test-Path -LiteralPath $parent)) {
        if ($DryRun) {
            Write-Info "would create $parent"
        } else {
            New-Item -ItemType Directory -Path $parent -Force | Out-Null
        }
    }

    if ($DryRun) {
        if ($onWindows) { Write-Info "would create junction $Target -> $Source" }
        else { Write-Info "would create symlink $Target -> $Source" }
        return
    }

    if ($onWindows) {
        New-Item -ItemType Junction -Path $Target -Target $Source | Out-Null
        Write-Ok "junction created: $Target -> $Source"
    } else {
        New-Item -ItemType SymbolicLink -Path $Target -Target $Source | Out-Null
        Write-Ok "symlink created: $Target -> $Source"
    }
}

Install-Link -Source $sourceNvim -Target $Target -Label 'nvim'
foreach ($t in $emacsTargets) {
    Install-Link -Source $sourceEmacs -Target $t -Label 'emacs'
}

# --- plugins -----------------------------------------------------------------

if ($NoPlugins) {
    Write-Info 'skipping plugin installation (-NoPlugins)'
} else {
    $nvimCmd = Get-Command nvim -ErrorAction SilentlyContinue
    if ($null -eq $nvimCmd) {
        Write-Warn 'nvim is not on PATH; skipping plugin installation'
    } elseif ($DryRun) {
        Write-Info 'would run: nvim --headless "+Lazy! restore" +qa'
    } else {
        Write-Step 'installing plugins from lazy-lock.json'
        & $nvimCmd.Source --headless '+Lazy! restore' +qa
        if ($LASTEXITCODE -ne 0) {
            Write-Warn 'Lazy restore failed; trying Lazy sync instead'
            & $nvimCmd.Source --headless '+Lazy! sync' +qa
            if ($LASTEXITCODE -ne 0) { Write-Warn 'plugin installation failed, open nvim and run :Lazy' }
        } else {
            Write-Ok 'plugins restored'
        }
    }
}

# --- lock drift --------------------------------------------------------------

if (-not $DryRun -and -not $NoPlugins -and (Test-Path -LiteralPath (Join-Path $repoRoot '.git'))) {
    $lockDirty = & git -C $repoRoot status --porcelain -- nvim/lazy-lock.json 2>$null
    if ($lockDirty) {
        Write-Warn 'lazy-lock.json still differs from the installed plugins (restore did not fully converge)'
        Write-Info "Treat the repo as the source of truth: git -C `"$repoRoot`" checkout -- nvim/lazy-lock.json"
        Write-Info 'To pin local versions: commit and push; otherwise the next -Update discards that drift'
    }
}

# --- done --------------------------------------------------------------------

Write-Host ''
if ($DryRun) {
    Write-Warn 'dry run complete. Re-run without -DryRun to apply.'
} else {
    if ($onWindows) {
        $dataDir = Join-Path $env:LOCALAPPDATA 'nvim-data'
    } else {
        $base = $env:XDG_DATA_HOME
        if ([string]::IsNullOrWhiteSpace($base)) { $base = Join-Path $HOME '.local/share' }
        $dataDir = Join-Path $base 'nvim'
    }
    Write-Ok 'done. Start nvim and wait for the first-run setup to finish.'
    Write-Info "nvim  : $Target"
    Write-Info "plugins: $dataDir (not versioned)"
    foreach ($t in $emacsTargets) { Write-Info "emacs : $t" }
    if ($null -ne (Get-Command emacs -ErrorAction SilentlyContinue)) {
        Write-Info 'Emacs does not auto-install: run M-x my/bootstrap-packages once inside it.'
    } else {
        Write-Warn 'emacs is not on PATH; once installed, run M-x my/bootstrap-packages inside it.'
    }
}

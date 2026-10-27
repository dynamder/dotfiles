#Requires -Version 5.1
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
    [string]$Target
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

$source = Join-Path $repoRoot 'nvim'
if (-not (Test-Path -LiteralPath (Join-Path $source 'init.lua'))) {
    throw 'Could not find nvim/init.lua next to this script. Run install.ps1 from the root of the dotfiles repository.'
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

# --- helpers -----------------------------------------------------------------

# Normalise a path for comparison: strip the \??\ / \\?\ prefix that Windows
# gives reparse points, resolve it, drop trailing separators, fold case.
function Resolve-RealPath {
    param([string]$Path)
    if ([string]::IsNullOrWhiteSpace($Path)) { return $null }
    $clean = $Path -replace '^\\\?\?\\', '' -replace '^\\\?\\', ''
    try { $clean = (Resolve-Path -LiteralPath $clean -ErrorAction Stop).ProviderPath } catch { }
    return ([string]$clean).TrimEnd('\', '/').ToLowerInvariant()
}

function Get-LinkTarget {
    param($Item)
    if ($null -eq $Item) { return $null }
    if (-not ($Item.PSObject.Properties.Name -contains 'LinkType')) { return $null }
    if (-not $Item.LinkType) { return $null }
    $targets = @($Item.Target) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
    if ($targets.Count -eq 0) { return $null }
    return [string]$targets[0]
}

# --- banner ------------------------------------------------------------------

Write-Step "dotfiles : $repoRoot"
Write-Step "nvim dir : $Target"
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
                # nvim 的配置目录就是仓库里的 nvim/，lazy.nvim 会就地重写
                # lazy-lock.json；本机插件版本与仓库锁定不一致就会弄脏工作树，
                # ff-only pull 随即被拒绝。锁文件以仓库为准，拉取前丢弃本机漂移。
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

# --- inspect what is already at the target -----------------------------------

$existing = Get-Item -LiteralPath $Target -Force -ErrorAction SilentlyContinue
$linkTarget = Get-LinkTarget $existing
$alreadyLinked = ($null -ne $linkTarget) -and
                 ((Resolve-RealPath $linkTarget) -eq (Resolve-RealPath $source))

if ($alreadyLinked) {
    Write-Ok "$Target already links to $source"
} else {
    if ($null -ne $existing) {
        $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
        if ($existing.LinkType) {
            $backup = "$Target.bak-$stamp"
            if ($DryRun) {
                Write-Info "would move stale link $Target -> $backup"
            } else {
                Move-Item -LiteralPath $Target -Destination $backup
                Write-Ok "stale link backed up to $backup"
            }
        } else {
            $backup = "$Target.bak-$stamp"
            if ($DryRun) {
                Write-Info "would move existing config $Target -> $backup"
            } else {
                Move-Item -LiteralPath $Target -Destination $backup
                Write-Ok "existing config backed up to $backup"
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
        if ($onWindows) { Write-Info "would create junction $Target -> $source" }
        else { Write-Info "would create symlink $Target -> $source" }
    } else {
        if ($onWindows) {
            New-Item -ItemType Junction -Path $Target -Target $source | Out-Null
            Write-Ok "junction created: $Target -> $source"
        } else {
            New-Item -ItemType SymbolicLink -Path $Target -Target $source | Out-Null
            Write-Ok "symlink created: $Target -> $source"
        }
    }
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
        Write-Warn 'lazy-lock.json 与本机实际插件版本仍不一致（restore 没能完全对齐）'
        Write-Info "以仓库为准: git -C `"$repoRoot`" checkout -- nvim/lazy-lock.json"
        Write-Info '要固定本机版本: commit 后 push；否则下次 -Update 会丢弃这里的漂移'
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
    Write-Info "config:  $Target"
    Write-Info "plugins: $dataDir (not versioned)"
}

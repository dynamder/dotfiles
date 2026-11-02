# Idempotency tests for install.ps1
#
# Every scenario runs the real installer against throwaway target directories
# inside <repo>/.install-test, using -Target / -EmacsTarget so the real config
# directories are never touched. -NoPlugins keeps nvim out of it.
#
# Run:  powershell -ExecutionPolicy Bypass -File .\tests\install-idempotency.ps1
#
# NOTE: keep this file pure ASCII (same reason as install.ps1).

$ErrorActionPreference = 'Stop'

$repo      = Split-Path -Parent $PSScriptRoot
$installer = Join-Path $repo 'install.ps1'
$root      = Join-Path $repo '.install-test'

if (-not (Test-Path -LiteralPath $installer)) {
    throw "cannot find install.ps1 at $installer"
}

$script:checks = 0
$script:fails  = 0

function Assert {
    param([bool]$Cond, [string]$Name, [string]$Detail = '')
    $script:checks++
    if ($Cond) {
        Write-Host ("  PASS  " + $Name)
    } else {
        Write-Host ("  FAIL  " + $Name + "   " + $Detail) -ForegroundColor Red
        $script:fails++
    }
}

function Assert-Eq {
    param($Actual, $Expected, [string]$Name)
    Assert ($Actual -eq $Expected) $Name ("actual=[" + $Actual + "] expected=[" + $Expected + "]")
}

function Run-Install {
    param([string]$Nvim, [string]$Emacs, [switch]$DryRun)
    $a = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $installer,
           '-NoPlugins', '-Target', $Nvim, '-EmacsTarget', $Emacs)
    if ($DryRun) { $a += '-DryRun' }
    & powershell @a 2>&1 | Out-String
}

function Link-Target {
    param([string]$Path)
    $i = Get-Item -LiteralPath $Path -Force -ErrorAction SilentlyContinue
    if ($null -eq $i) { return '<missing>' }
    if (-not $i.LinkType) { return '<real-dir>' }
    $t = @($i.Target | Where-Object { $_ })
    if ($t.Count -eq 0) { return '<no-target>' }
    return ([string]$t[0]) -replace '^Global\\', ''
}

function Backup-Names {
    param([string]$Dir)
    @(Get-ChildItem -LiteralPath $Dir -Force -ErrorAction SilentlyContinue |
      Where-Object { $_.Name -like '*.bak-*' } | ForEach-Object { $_.Name })
}

function Reset-Dir {
    param([string]$Path)
    if (Test-Path -LiteralPath $Path) { Remove-Item -LiteralPath $Path -Recurse -Force }
    New-Item -ItemType Directory -Path $Path -Force | Out-Null
}

New-Item -ItemType Directory -Path $root -Force | Out-Null

# --- 1. fresh install, run twice ---------------------------------------------

Write-Host "`n[1] fresh install x2"
$d = Join-Path $root 's1'
Reset-Dir $d

$null = Run-Install (Join-Path $d 'nvim') (Join-Path $d 'emacs')
Assert-Eq (Link-Target (Join-Path $d 'nvim'))  (Join-Path $repo 'nvim')  'run 1: nvim links to repo'
Assert-Eq (Link-Target (Join-Path $d 'emacs')) (Join-Path $repo 'emacs') 'run 1: emacs links to repo'
Assert (Test-Path -LiteralPath (Join-Path $d 'nvim\init.lua')) 'run 1: nvim/init.lua readable through link'
Assert (Test-Path -LiteralPath (Join-Path $d 'emacs\init.el')) 'run 1: emacs/init.el readable through link'
Assert-Eq (Backup-Names $d).Count 0 'run 1: no backups created'

$out = Run-Install (Join-Path $d 'nvim') (Join-Path $d 'emacs')
Assert-Eq (Link-Target (Join-Path $d 'nvim'))  (Join-Path $repo 'nvim')  'run 2: nvim still links to repo'
Assert-Eq (Link-Target (Join-Path $d 'emacs')) (Join-Path $repo 'emacs') 'run 2: emacs still links to repo'
Assert-Eq (Backup-Names $d).Count 0 'run 2: no extra backups'
Assert ($out -notmatch 'stale|backed up|would move') 'run 2: nothing was touched'

# --- 2. real directories already at the target -------------------------------

Write-Host "`n[2] real directories already present"
$d = Join-Path $root 's2'
Reset-Dir $d

New-Item -ItemType Directory -Path (Join-Path $d 'nvim') -Force | Out-Null
Set-Content -LiteralPath (Join-Path $d 'nvim\init.lua') -Value '-- old config'
New-Item -ItemType Directory -Path (Join-Path $d 'emacs') -Force | Out-Null
Set-Content -LiteralPath (Join-Path $d 'emacs\init.el') -Value ';; old config'

$null = Run-Install (Join-Path $d 'nvim') (Join-Path $d 'emacs')
Assert-Eq (Link-Target (Join-Path $d 'nvim')) (Join-Path $repo 'nvim') 'run 1: old dir replaced by link'
Assert-Eq (Backup-Names $d).Count 2 'run 1: two backups created'

$bakName = (Backup-Names $d) | Where-Object { $_ -like 'nvim.bak-*' } | Select-Object -First 1
$bakInit = Join-Path (Join-Path $d $bakName) 'init.lua'
Assert (Test-Path -LiteralPath $bakInit) 'backup keeps the old file'
Assert-Eq ((Get-Content -LiteralPath $bakInit -Raw).Trim()) '-- old config' 'backup content intact'

$null = Run-Install (Join-Path $d 'nvim') (Join-Path $d 'emacs')
Assert-Eq (Backup-Names $d).Count 2 'run 2: no extra backups'

# --- 3. target is a link pointing somewhere else -----------------------------

Write-Host "`n[3] target is a link pointing elsewhere (no backup, must not delete its target)"
$d = Join-Path $root 's3'
Reset-Dir $d
$elsewhere = Join-Path $d 'elsewhere'
New-Item -ItemType Directory -Path $elsewhere -Force | Out-Null
Set-Content -LiteralPath (Join-Path $elsewhere 'keep.txt') -Value 'keep me'
New-Item -ItemType Junction -Path (Join-Path $d 'nvim') -Target $elsewhere | Out-Null

$null = Run-Install (Join-Path $d 'nvim') (Join-Path $d 'emacs')
Assert-Eq (Link-Target (Join-Path $d 'nvim')) (Join-Path $repo 'nvim') 'stale link repointed at repo'
Assert-Eq (Backup-Names $d).Count 0 'links are not backed up'
Assert (Test-Path -LiteralPath (Join-Path $elsewhere 'keep.txt')) 'the old link target survived'

$null = Run-Install (Join-Path $d 'nvim') (Join-Path $d 'emacs')
Assert-Eq (Backup-Names $d).Count 0 'run again creates no backups'

# --- 4. target is a broken link ----------------------------------------------

Write-Host "`n[4] target is a broken link"
$d = Join-Path $root 's4'
Reset-Dir $d
$gone = Join-Path $d 'gone'
New-Item -ItemType Directory -Path $gone -Force | Out-Null
New-Item -ItemType Junction -Path (Join-Path $d 'nvim') -Target $gone | Out-Null
Remove-Item -LiteralPath $gone -Recurse -Force

$out = Run-Install (Join-Path $d 'nvim') (Join-Path $d 'emacs')
Assert-Eq (Link-Target (Join-Path $d 'nvim')) (Join-Path $repo 'nvim') 'broken link repaired'
Assert ($out -notmatch 'Move-Item|Exception|cannot find|Could not find') 'repair raised no error'

$out2 = Run-Install (Join-Path $d 'nvim') (Join-Path $d 'emacs')
Assert-Eq (Link-Target (Join-Path $d 'nvim')) (Join-Path $repo 'nvim') 'second run still correct'
Assert ($out2 -notmatch 'stale|backed up|would move') 'second run touched nothing'

# --- 5. dry run has no side effects ------------------------------------------

Write-Host "`n[5] dry run has no side effects"
$d = Join-Path $root 's5'
Reset-Dir $d
New-Item -ItemType Directory -Path (Join-Path $d 'nvim') -Force | Out-Null
Set-Content -LiteralPath (Join-Path $d 'nvim\init.lua') -Value '-- old config'

$null = Run-Install (Join-Path $d 'nvim') (Join-Path $d 'emacs') -DryRun
Assert-Eq (Link-Target (Join-Path $d 'nvim')) '<real-dir>' 'dry run left the real dir alone'
Assert (-not (Test-Path -LiteralPath (Join-Path $d 'emacs'))) 'dry run created no link'
Assert-Eq (Backup-Names $d).Count 0 'dry run created no backup'

# --- 6. two runs within the same second (backup name collision) --------------

Write-Host "`n[6] two runs within the same second"
$d = Join-Path $root 's6'
Reset-Dir $d
New-Item -ItemType Directory -Path (Join-Path $d 'nvim') -Force | Out-Null
Set-Content -LiteralPath (Join-Path $d 'nvim\init.lua') -Value '-- old config'
New-Item -ItemType Directory -Path (Join-Path $d 'emacs') -Force | Out-Null

$null = Run-Install (Join-Path $d 'nvim') (Join-Path $d 'emacs')
# Turn the nvim target back into a real dir and rerun immediately, so the
# timestamp-based backup name is very likely to collide.
Remove-Item -LiteralPath (Join-Path $d 'nvim') -Recurse -Force
New-Item -ItemType Directory -Path (Join-Path $d 'nvim') -Force | Out-Null
$out = Run-Install (Join-Path $d 'nvim') (Join-Path $d 'emacs')
Assert ($out -notmatch 'Exception|already exists|cannot create') 'second backup did not collide'
Assert-Eq (Link-Target (Join-Path $d 'nvim')) (Join-Path $repo 'nvim') 'second run still links correctly'

# --- summary -----------------------------------------------------------------

Write-Host ("`n===== " + $script:checks + " checks, " + $script:fails + " failed =====")
if ($script:fails -gt 0) { exit 1 } else { exit 0 }

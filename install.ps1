# Blade Build installer for Windows (PowerShell).
#
#   irm https://blade-build.github.io/install.ps1 | iex
#
# Mirrors install.sh: clone (or update) blade-build into %LOCALAPPDATA%\blade-build
# and make the `blade` command available -- here by adding that dir (which
# holds blade.bat) to your user PATH.
#
# Environment overrides (all optional):
#   BLADE_REPO            source repo/URL   (default: the GitHub repo)
#   BLADE_INSTALL_DIR     install location  (default: %LOCALAPPDATA%\blade-build)
#   BLADE_NO_MODIFY_PATH  set to 1 to skip the PATH change (CI / testing)
#   BLADE_NONINTERACTIVE  set to 1 to never prompt (e.g. the winget Ninja offer)

$ErrorActionPreference = 'Stop'

function Install-Ninja {
    # Ninja is blade's build backend. When it is missing, offer to install it
    # via winget (stable package id); fall back to a hint otherwise.
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        Write-Host "Note: 'ninja' is not on PATH; blade needs Ninja 1.10+ (https://ninja-build.org)." -ForegroundColor Yellow
        return
    }
    if (-not [Environment]::UserInteractive -or $env:BLADE_NONINTERACTIVE -eq '1') {
        Write-Host "Note: 'ninja' is not on PATH; install it with: winget install Ninja-build.Ninja" -ForegroundColor Yellow
        return
    }
    $answer = Read-Host "Ninja (blade's build backend) was not found. Install it now with winget? [Y/n]"
    if ($answer -match '^\s*[Nn]') {
        Write-Host "Skipped. Install it later with: winget install Ninja-build.Ninja" -ForegroundColor Yellow
        return
    }
    Write-Host "Installing Ninja via winget ..." -ForegroundColor Cyan
    winget install --id Ninja-build.Ninja -e --source winget --accept-source-agreements --accept-package-agreements
    if (Get-Command ninja -ErrorAction SilentlyContinue) {
        Write-Host "Ninja installed." -ForegroundColor Green
    } else {
        Write-Host "Ninja installed; open a new terminal for it to appear on PATH." -ForegroundColor Yellow
    }
}

function Test-Python310 {
    # blade.bat runs `python.exe`, so verify `python` resolves to Python >= 3.10
    # by asking Python itself (robust -- no --version string parsing). The
    # Microsoft Store alias stub exits non-zero here, so it reads as "missing".
    if (-not (Get-Command python -ErrorAction SilentlyContinue)) { return $false }
    try {
        & python -c 'import sys; sys.exit(0 if sys.version_info >= (3, 10) else 1)' *> $null
        return ($LASTEXITCODE -eq 0)
    } catch { return $false }
}

function Install-Blade {
    $repo = if ($env:BLADE_REPO) { $env:BLADE_REPO } else { 'https://github.com/blade-build/blade-build' }
    $dir  = if ($env:BLADE_INSTALL_DIR) { $env:BLADE_INSTALL_DIR } else { Join-Path $env:LOCALAPPDATA 'blade-build' }

    # Migrate an install from the old ~/.cache location (pre-2026-06 layout).
    $legacy = Join-Path $HOME '.cache\blade-build'
    if ((Test-Path (Join-Path $legacy '.git')) -and -not (Test-Path $dir) -and ($dir -ne $legacy)) {
        Write-Host "Moving existing install from $legacy to $dir ..." -ForegroundColor Cyan
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $dir) | Out-Null
        Move-Item -Path $legacy -Destination $dir
    }

    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        throw "git is required but was not found. Install it (winget install Git.Git) or from https://git-scm.com/download/win"
    }

    if (Test-Path (Join-Path $dir '.git')) {
        Write-Host "Updating blade-build in $dir ..." -ForegroundColor Cyan
        git -C $dir pull --ff-only
    } else {
        Write-Host "Cloning blade-build into $dir ..." -ForegroundColor Cyan
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $dir) | Out-Null
        git clone --depth 1 $repo $dir
    }
    if ($LASTEXITCODE -ne 0) { throw "git failed (exit $LASTEXITCODE)." }

    $launcher = Join-Path $dir 'blade.bat'
    if (-not (Test-Path $launcher)) { throw "blade.bat not found in $dir after install." }

    if ($env:BLADE_NO_MODIFY_PATH -ne '1') {
        $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
        $entries  = if ($userPath) { @($userPath -split ';') } else { @() }
        # Put $dir on PATH, dropping any stale entry pointing at the old location.
        $kept    = $entries | Where-Object { $_ -and $_ -ne $dir -and $_ -ne $legacy }
        $newPath = (@($dir) + $kept) -join ';'
        if ($newPath -ne $userPath) {
            Write-Host "Updating your user PATH ..." -ForegroundColor Cyan
            [Environment]::SetEnvironmentVariable('Path', $newPath, 'User')
        }
        $env:Path = "$dir;$env:Path"   # make `blade` work in the current session too
    }

    # blade needs Python 3.10+ and Ninja at run time. Warn if Python is missing;
    # for Ninja -- which has a stable winget package -- offer to install it.
    if (-not (Test-Python310)) {
        Write-Host "Note: no Python 3.10+ found as 'python'; blade needs Python 3.10+ (winget install Python.Python.3.13)." -ForegroundColor Yellow
    }
    if (-not (Get-Command ninja -ErrorAction SilentlyContinue)) {
        Install-Ninja
    }

    Write-Host ""
    Write-Host "blade installed to $dir" -ForegroundColor Green
    Write-Host "Open a new terminal (so the PATH change takes effect) and run:  blade --help" -ForegroundColor Green
}

Install-Blade

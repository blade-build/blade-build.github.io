# Blade Build installer for Windows (PowerShell).
#
#   irm https://blade-build.github.io/install.ps1 | iex
#
# Mirrors install.sh: clone (or update) blade-build into ~/.cache/blade-build
# and make the `blade` command available -- here by adding that dir (which
# holds blade.bat) to your user PATH.
#
# Environment overrides (all optional):
#   BLADE_REPO            source repo/URL   (default: the GitHub repo)
#   BLADE_INSTALL_DIR     install location  (default: ~/.cache/blade-build)
#   BLADE_NO_MODIFY_PATH  set to 1 to skip the PATH change (CI / testing)

$ErrorActionPreference = 'Stop'

function Install-Blade {
    $repo = if ($env:BLADE_REPO) { $env:BLADE_REPO } else { 'https://github.com/blade-build/blade-build' }
    $dir  = if ($env:BLADE_INSTALL_DIR) { $env:BLADE_INSTALL_DIR } else { Join-Path $HOME '.cache\blade-build' }

    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        throw "git is required but was not found. Install it from https://git-scm.com/download/win"
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
        $entries  = if ($userPath) { $userPath -split ';' } else { @() }
        if ($entries -notcontains $dir) {
            Write-Host "Adding $dir to your user PATH ..." -ForegroundColor Cyan
            $newPath = if ($userPath) { "$dir;$userPath" } else { $dir }
            [Environment]::SetEnvironmentVariable('Path', $newPath, 'User')
        }
        $env:Path = "$dir;$env:Path"   # make `blade` work in the current session too
    }

    # blade needs Python 3.10+ and Ninja at run time -- warn, don't fail (parity
    # with install.sh, which assumes prerequisites are present).
    foreach ($tool in 'python', 'ninja') {
        if (-not (Get-Command $tool -ErrorAction SilentlyContinue)) {
            Write-Host "Note: '$tool' is not on PATH; blade needs it (Python 3.10+ and Ninja 1.10+)." -ForegroundColor Yellow
        }
    }

    Write-Host ""
    Write-Host "blade installed to $dir" -ForegroundColor Green
    Write-Host "Open a new terminal (so the PATH change takes effect) and run:  blade --help" -ForegroundColor Green
}

Install-Blade

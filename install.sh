#!/bin/bash
#
# Blade Build installer for Linux and macOS.
#
#   curl -fsSL https://blade-build.github.io/install.sh | bash
#
# Clones (or updates) blade-build into ~/.cache/blade-build and runs its
# ./install, which puts the `blade` command on your PATH.
#
# Environment overrides (optional):
#   BLADE_REPO          source repo/URL  (default: the GitHub repo)
#   BLADE_INSTALL_DIR   install location (default: ~/.cache/blade-build)

set -euo pipefail

repo="${BLADE_REPO:-https://github.com/blade-build/blade-build}"
dir="${BLADE_INSTALL_DIR:-$HOME/.cache/blade-build}"

if ! command -v git >/dev/null 2>&1; then
    echo "error: git is required but was not found. Please install git first." >&2
    exit 1
fi

if [[ -d "$dir/.git" ]]; then
    echo "Updating blade-build in $dir ..."
    git -C "$dir" pull --ff-only
else
    echo "Cloning blade-build into $dir ..."
    mkdir -p "$(dirname "$dir")"
    git clone --depth 1 "$repo" "$dir"
fi

cd "$dir"
./install

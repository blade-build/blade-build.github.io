#!/bin/bash
#
# Blade Build installer for Linux and macOS.
#
#   curl -fsSL https://blade-build.github.io/install.sh | bash
#
# Clones (or updates) blade-build into ~/.local/share/blade-build and runs its
# ./install, which puts the `blade` command on your PATH. If Ninja (the build
# backend) is missing, offers to install it with your package manager.
#
# Environment overrides (optional):
#   BLADE_REPO            source repo/URL  (default: the GitHub repo)
#   BLADE_INSTALL_DIR     install location (default: ~/.local/share/blade-build)
#   BLADE_NONINTERACTIVE  set to 1 to never prompt (e.g. the Ninja install offer)

set -euo pipefail

# Ask a yes/no question (default yes) on the controlling terminal -- works even
# when the script itself arrived on stdin via `curl | bash`. Returns 0 for yes;
# returns 1 (no) when non-interactive or BLADE_NONINTERACTIVE=1.
prompt_yes_no() {
    local question="$1" answer
    if [[ "${BLADE_NONINTERACTIVE:-}" == "1" ]]; then return 1; fi
    if [[ ! -e /dev/tty ]]; then return 1; fi
    printf '%s [Y/n] ' "$question" > /dev/tty
    if ! read -r answer < /dev/tty; then return 1; fi
    [[ -z "$answer" || "$answer" =~ ^[Yy] ]]
}

# Offer to install Ninja with the platform's package manager. Best-effort: on
# decline, no known manager, or failure, fall back to a copy-pasteable hint.
offer_install_ninja() {
    local mgr="" cmd=""
    if [[ "$(uname -s)" == "Darwin" ]]; then
        if command -v brew >/dev/null 2>&1; then
            mgr="Homebrew"; cmd="brew install ninja"
        elif command -v port >/dev/null 2>&1; then
            mgr="MacPorts"; cmd="sudo port install ninja"
        fi
    else
        if command -v apt-get >/dev/null 2>&1; then
            mgr="apt"; cmd="apt-get install -y ninja-build"
        elif command -v dnf >/dev/null 2>&1; then
            mgr="dnf"; cmd="dnf install -y ninja-build"
        elif command -v yum >/dev/null 2>&1; then
            mgr="yum"; cmd="yum install -y ninja-build"
        elif command -v pacman >/dev/null 2>&1; then
            mgr="pacman"; cmd="pacman -S --noconfirm ninja"
        elif command -v zypper >/dev/null 2>&1; then
            mgr="zypper"; cmd="zypper install -y ninja"
        elif command -v apk >/dev/null 2>&1; then
            mgr="apk"; cmd="apk add ninja-build"
        fi
        # System package managers need root.
        if [[ -n "$cmd" && "${EUID:-$(id -u)}" -ne 0 ]] && command -v sudo >/dev/null 2>&1; then
            cmd="sudo $cmd"
        fi
    fi

    if [[ -z "$cmd" ]]; then
        echo "Note: 'ninja' is not on PATH; blade needs Ninja 1.10+ (https://ninja-build.org)."
        return 0
    fi
    if prompt_yes_no "Ninja (blade's build backend) was not found. Install it with $mgr ($cmd)?"; then
        echo "Installing Ninja: $cmd"
        if eval "$cmd"; then
            echo "Ninja installed."
        else
            echo "Note: install failed; install Ninja manually (https://ninja-build.org)." >&2
        fi
    else
        echo "Skipped. Install it later with: $cmd"
    fi
}

repo="${BLADE_REPO:-https://github.com/blade-build/blade-build}"
dir="${BLADE_INSTALL_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/blade-build}"

# Migrate an install from the old ~/.cache location (pre-2026-06 layout).
legacy="$HOME/.cache/blade-build"
if [[ -d "$legacy/.git" && ! -e "$dir" && "$dir" != "$legacy" ]]; then
    echo "Moving existing install from $legacy to $dir ..."
    mkdir -p "$(dirname "$dir")"
    mv "$legacy" "$dir"
fi

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

# Best-effort prerequisite help (blade needs Python 3.10+ and Ninja at runtime).
# Probe for a >=3.10 interpreter by asking Python itself (sys.version_info) via
# its exit code -- robust, unlike parsing --version (format/locale/stderr).
have_python310() {
    local py
    for py in python3 python python3.13 python3.12 python3.11 python3.10; do
        if command -v "$py" >/dev/null 2>&1 && \
           "$py" -c 'import sys; sys.exit(0 if sys.version_info >= (3, 10) else 1)' 2>/dev/null; then
            return 0
        fi
    done
    return 1
}
if ! have_python310; then
    echo "Note: no Python 3.10+ found on PATH; blade needs Python 3.10+."
fi
if ! command -v ninja >/dev/null 2>&1; then
    offer_install_ninja
fi

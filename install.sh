#!/usr/bin/env bash
set -euo pipefail
if (( EUID == 0 )); then
    printf '%s\n' 'Run MiraOS Dots as your regular user.' >&2
    exit 1
fi
repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
if ! command -v python >/dev/null; then
    if [[ ! -r /etc/os-release ]] || ! grep -Eq '^ID=(arch|"arch")$' /etc/os-release || ! command -v pacman >/dev/null; then
        printf '%s\n' 'MiraOS Dots requires Arch Linux and Python.' >&2
        exit 1
    fi
    for arg in "$@"; do
        case "$arg" in
            --dry-run|--help|-h) printf '%s\n' 'Install Python to run the installer. Use sudo pacman -Syu --needed python.' >&2; exit 1 ;;
        esac
    done
    read -r -p 'Install Python with pacman and upgrade the system? [y/N] ' answer
    [[ "$answer" == y || "$answer" == Y ]] || exit 1
    sudo pacman -Syu --needed python
fi
exec python -B "$repo/scripts/installer.py" install "$@"

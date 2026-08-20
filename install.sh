#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
target_dir="${STOW_TARGET:-$HOME}"

all_packages=(
  btop cava containers desktop easyeffects fastfetch git glow helium hypr imv
  kitty mpv nsxiv nvim pacman paru pinentry quickshell scripts systemd theme
  uwsm yazi zsh
)

action="${1:-install}"
if (($# > 0)); then
  shift
fi

if (($# > 0)); then
  selected_packages=("$@")
else
  selected_packages=("${all_packages[@]}")
fi

case "$action" in
  install)
    stow --dir="$repo_dir" --target="$target_dir" --restow --verbose=1 \
      "${selected_packages[@]}"
    ;;
  remove)
    stow --dir="$repo_dir" --target="$target_dir" --delete --verbose=1 \
      "${selected_packages[@]}"
    ;;
  check)
    stow --dir="$repo_dir" --target="$target_dir" --restow --simulate --verbose=2 \
      "${selected_packages[@]}"
    ;;
  *)
    printf 'Usage: %s [install|remove|check] [package ...]\n' "$0" >&2
    exit 2
    ;;
esac

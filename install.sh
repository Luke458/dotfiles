#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
target_dir="${STOW_TARGET:-$HOME}"

if ! command -v stow >/dev/null 2>&1; then
  printf 'GNU Stow is required but was not found on PATH.\n' >&2
  exit 1
fi

all_packages=(
  btop cava containers desktop easyeffects fastfetch git glow helium hypr imv
  kitty mpv nvim pacman paru pinentry quickshell scripts systemd theme
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

stow_cmd() {
  stow --dir="$repo_dir" --target="$target_dir" "$@"
}

require_commands() {
  local missing=0 command_name
  for command_name in "$@"; do
    if ! command -v "$command_name" >/dev/null 2>&1; then
      printf 'missing required command: %s\n' "$command_name" >&2
      missing=1
    fi
  done
  return "$missing"
}

doctor() {
  require_commands stow git || true

  local optional
  for optional in rg jq systemctl gitleaks; do
    if ! command -v "$optional" >/dev/null 2>&1; then
      printf 'optional command not found: %s\n' "$optional"
    fi
  done

  printf '\n-- stow conflicts --\n'
  local conflicts
  conflicts="$(stow_cmd --restow --simulate --verbose=1 "${all_packages[@]}" 2>&1 |
    grep -E 'CONFLICT|cannot stow' || true)"
  if [ -n "$conflicts" ]; then
    printf '%s\n' "$conflicts"
    printf '\nResolve the listed targets before installing (see README).\n'
  else
    printf 'none\n'
  fi

  printf '\n-- git working tree --\n'
  if [ -d "$repo_dir/.git" ]; then
    if [ -n "$(git -C "$repo_dir" status --porcelain)" ]; then
      git -C "$repo_dir" status --short
    else
      printf 'clean\n'
    fi
  else
    printf 'not a git checkout\n'
  fi

  printf '\n-- package list drift --\n'
  if command -v pacman >/dev/null 2>&1; then
    if diff <(pacman -Qqen | LC_ALL=C sort -u) "$repo_dir/packages/arch-repo.txt" >/dev/null; then
      printf 'repo list is current\n'
    else
      printf 'repo list differs; run packages/update.sh\n'
    fi
    if diff <(pacman -Qqem | LC_ALL=C sort -u) "$repo_dir/packages/arch-aur.txt" >/dev/null; then
      printf 'AUR list is current\n'
    else
      printf 'AUR list differs; run packages/update.sh\n'
    fi
  else
    printf 'pacman not available; skipped\n'
  fi
}

install_deps() {
  require_commands pacman
  printf 'Installing official-repository packages...\n'
  # shellcheck disable=SC2046  # intentional word splitting of the package list
  sudo pacman -S --needed -- $(cat "$repo_dir/packages/arch-repo.txt")
  if command -v paru >/dev/null 2>&1; then
    printf 'Installing AUR packages...\n'
    # shellcheck disable=SC2046
    paru -S --needed -- $(cat "$repo_dir/packages/arch-aur.txt")
  else
    printf 'paru not found; install it before the AUR packages.\n' >&2
  fi
}

case "$action" in
  install)
    stow_cmd --restow --verbose=1 "${selected_packages[@]}"
    ;;
  remove)
    stow_cmd --delete --verbose=1 "${selected_packages[@]}"
    ;;
  check)
    stow_cmd --restow --simulate --verbose=2 "${selected_packages[@]}"
    ;;
  doctor)
    doctor
    ;;
  deps)
    install_deps
    ;;
  *)
    printf 'Usage: %s [install|remove|check|doctor|deps] [package ...]\n' "$0" >&2
    exit 2
    ;;
esac

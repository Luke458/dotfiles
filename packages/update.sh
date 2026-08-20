#!/usr/bin/env bash
set -euo pipefail

package_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

pacman -Qqen | LC_ALL=C sort -u > "$package_dir/arch-repo.txt"
pacman -Qqem | LC_ALL=C sort -u > "$package_dir/arch-aur.txt"

printf 'Updated %s and %s\n' \
  "$package_dir/arch-repo.txt" "$package_dir/arch-aur.txt"

# Luke's dotfiles

Personal Arch/CachyOS, Hyprland, and Quickshell configuration managed with
[GNU Stow](https://www.gnu.org/software/stow/) and Git.

## Install

```sh
git clone git@github.com:Luke458/dotfiles.git ~/dotfiles
cd ~/dotfiles
./install.sh check
./install.sh install
```

`install.sh` targets `$HOME` by default. Set `STOW_TARGET` to validate or install
against another home directory. A subset can be managed by naming packages:

```sh
./install.sh install zsh git kitty nvim
./install.sh remove kitty
```

Stow intentionally refuses to overwrite conflicting files. Back up an existing
configuration before installing. If adopting files from another machine, use
`stow --adopt` only after making a backup, then inspect `git diff` because the
target files become the repository copies.

## Packages

- Desktop shell: `hypr`, `quickshell`, `uwsm`, `wofi`, `desktop`, `theme`
- Terminal and shell: `zsh`, `kitty`, `git`
- Editors and file tools: `nvim`, `yazi`, `imv`, `nsxiv`
- Media and monitoring: `mpv`, `cava`, `btop`, `htop`, `fastfetch`, `easyeffects`
- System integration: `systemd`, `containers`, `pinentry`, `helium`, `scripts`
- Package tooling: `pacman`, `paru`

The `packages/` directory records explicitly installed official-repository and
AUR/foreign packages. Refresh those lists with `packages/update.sh`.

## Quadlets

The `containers` package tracks the five media-stack `.container` Quadlets and
their `.network` unit. The `systemd` package tracks `media-stack.target` and the
enabled user-unit links. Reload generated units after changing a Quadlet:

```sh
systemctl --user daemon-reload
systemctl --user restart media-stack.target
```

## Automatic synchronization

`dotfiles-sync.timer` checks hourly, with a small randomized delay. It refreshes
the Arch package lists, commits tracked changes, and pushes `main` when the
remote is still an ancestor of the local branch.

The sync deliberately refuses credential signatures, whitespace errors, a
pre-staged index, and remote divergence. New untracked files are reported in the
journal but are never added or published automatically.

```sh
systemctl --user enable --now dotfiles-sync.timer
systemctl --user list-timers dotfiles-sync.timer
journalctl --user-unit dotfiles-sync.service
```

## Host-specific dependencies

Some configuration deliberately references this host's paths and services:

- Hyprland and Quickshell use `/home/luke` paths.
- The `sbr` launcher points to `/home/luke/Projects/sing-box-routes/bin/sbr`.
- Media Quadlets expect `/home/luke/media-stack` and `/home/luke/data`.
- The Hermes wrappers and service expect `/home/luke/.hermes`.
- The Quickshell pinentry executable is a generated build at
  `~/.local/bin/pinentry-quickshell`; its source is tracked, but the binary is not.
- Wallpaper files and application data are not tracked.

## Deliberate exclusions

Credentials and mutable application state are excluded even though the GitHub
repository is private. This includes SSH private keys, GitHub and Rclone auth,
password stores, browser profiles/cookies/history, Pulse cookies, caches, logs,
downloaded models, and generated build directories.

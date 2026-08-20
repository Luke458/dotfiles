# Quickshell Hyprland Config

A modular desktop shell for Hyprland built with Quickshell `0.3.0`.

## Features
- **Multi-monitor bar:** Independent bars for each monitor.
- **Hyprland integration:** Workspace tracking, window titles, layout indicator, and dispatch commands.
- **Universal launcher:** Desktop entry search plus native password-store and power pickers.
- **System monitoring:** CPU, memory, AMD GPU, disk usage, and focused detail popups.
- **Service-backed data:** Weather via Open-Meteo, BTC chart/price data via `services/Btc.qml`, Mullvad via `services/Mullvad.qml`, and audio via PipeWire.
- **Interactivity:** Volume scroll/mute, Mullvad VPN controls, idle inhibition, system tray menus, notifications, media controls, lock screen, and power controls.

## Architecture

```text
.
├── shell.qml                 # Entry point; instantiates bars, notifications, lock surface
├── launcher.qml              # Standalone app launcher
├── pass.qml                  # Standalone password-store picker
├── power.qml                 # Standalone dmenu-style power picker
├── windows/
│   ├── Bar.qml               # PanelWindow layout and module composition
│   └── Lockscreen.qml        # WlSessionLock surface
├── components/
│   ├── BtcTicker.qml         # Bar BTC summary backed by services/Btc.qml
│   ├── BtcDetails.qml        # BTC chart/details popup
│   ├── MullvadIndicator.qml  # Bar VPN indicator backed by services/Mullvad.qml
│   ├── MullvadDetails.qml    # Mullvad replacement popup
│   ├── AdvancedWeatherDetails.qml
│   ├── ShellPopup.qml        # PopupWindow flyout container
│   ├── Tray.qml / TrayMenu.qml
│   └── qmldir
├── services/
│   ├── Btc.qml               # CoinGecko/Coinbase-backed BTC service
│   ├── Weather.qml           # Open-Meteo weather service
│   ├── Mullvad.qml           # mullvad-cli status, relay, and settings service
│   ├── LayoutState.qml       # Shared Hyprland layout state and switching
│   ├── Stats.qml             # /proc, /sys, lsblk, df, and ps-backed system stats
│   ├── Volume.qml            # PipeWire volume/mixer service
│   ├── Notifications.qml     # Optional notification server/history service
│   └── qmldir
├── scripts/
│   ├── btc_chart.sh          # One-shot BTC chart fetch for services/Btc.qml
│   ├── build-pinentry-plugin # Builds the config-owned Pinentry QML module
│   ├── install-pinentry-plugin
│   └── qs                    # Starts Quickshell with the module import path
├── plugins/
│   └── pinentry/             # C++ QML module and pinentry-quickshell helper
└── assets/
    └── helium.svg
```

## Runtime Notes

- Target Quickshell: `0.3.0`.
- Popups use `PopupWindow` with `anchor.window`/`anchor.rect` positioning.
- Bar-level CPU, memory, and GPU utilization is polled every 2 seconds. Detailed clocks, thermals, and process lists are collected only while their popups are open.
- Launcher, password, and power pickers renew a short bar-visibility lease so a crashed picker cannot leave a monitor bar hidden.
- Notification history is capped, ignores transient notifications, follows replacement updates, and respects application timeout requests.
- `QS_NOTIFICATION_SERVER=auto|on|off` controls notification ownership. `auto` creates Quickshell's server only when no existing DBus owner is present.
- `QS_DISABLE_NOTIFICATION_SERVER=1` is kept as an alias for `QS_NOTIFICATION_SERVER=off`.
- `QS_DEBUG_NOTIFICATIONS=1` enables sanitized notification debug logs.
- `QS_DEBUG_PINENTRY=1` enables pinentry lifecycle logs without recording prompt titles, key IDs, or secrets.
- The GPG prompt bridge is the local `Luke.Quickshell.Pinentry` QML module. Use `scripts/qs` so Quickshell can find its build-tree module during development or the installed module in normal use.
- `scripts/install-pinentry-plugin` installs both the module and `pinentry-quickshell` under `~/.local` by default. The configured GPG agent helper path is `~/.local/bin/pinentry-quickshell`; reload it with `gpgconf --reload gpg-agent` after installation.
- `scripts/qs` launches `~/.local/bin/quickshell`, matching the Hyprland startup configuration. Set `QUICKSHELL_BIN` to use a different Quickshell installation.

## Development Guidelines

- Keep UI components in `components/`, shell windows in `windows/`, and long-lived state/integrations in `services/`.
- Prefer service-backed data over per-widget polling or streaming scripts.
- Use `SplitParser` for line-oriented process output and `StdioCollector` for full-output parsing.
- Use `Theme.qml` for colors unless a component intentionally represents semantic status.
- Register new components and singletons in the relevant `qmldir`.

## Common Commands

```bash
scripts/build-pinentry-plugin
scripts/qs
scripts/qs log --tail 200
scripts/qs -p launcher.qml
scripts/qs -p pass.qml
scripts/qs -p power.qml

# Install the helper used by gpg-agent and the QML module under ~/.local.
scripts/install-pinentry-plugin
gpgconf --reload gpg-agent
```

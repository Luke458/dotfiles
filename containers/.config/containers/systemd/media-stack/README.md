# Media Stack Quadlets

These Quadlet units are the whole stack: `/home/luke/media-stack/` now holds only
the apps' `config/` trees (the legacy `docker-compose.yml` mirror was removed, as
was `media-stack.network` — no unit uses a container network any more).

Reload generated services:

```sh
systemctl --user daemon-reload
```

Start or stop the whole stack:

```sh
systemctl --user start media-stack.target
systemctl --user stop media-stack.target
```

Start on user login:

```sh
systemctl --user enable media-stack.target
```

Start from boot without an interactive login:

```sh
loginctl enable-linger luke
systemctl --user enable media-stack.target
```

Update images:

```sh
podman auto-update --dry-run
podman auto-update
```

Notes:

- **Every container runs with `Network=host`.** Rootless bridged networking on
  this host (netavark + pasta in podman's rootless netns) drops all external
  UDP, which killed DHT, uTP and 4 of every 5 trackers per torrent. On host
  networking the whole stack shares one netns, so every cross-service URL is
  `127.0.0.1`; `media-stack.network` and the legacy `docker-compose.yml` mirror
  were both deleted — no unit uses a container network any more.
- Server-to-server URLs are loopback because of the above: Sonarr/Radarr
  download client `127.0.0.1:8080`, Prowlarr → `127.0.0.1:8989`/`:7878` and
  `prowlarrUrl 127.0.0.1:9696`, Sonarr/Radarr "Emby / Jellyfin" connect target
  `127.0.0.1:8096`.
- qBittorrent's WebUI binds `127.0.0.1:8080` (`WebUI\Address`), so it stays off
  the LAN even though the container shares the host netns. Its torrent port
  `6881/tcp` + `6881/udp` listens only on the Mullvad interface (see VPN below);
  inbound still needs forwarding from Mullvad to leave "connected, no inbound".
- qBittorrent's interface pin must name a real host interface. It was left
  pointing at `eth0`, which existed only under bridged networking, and with host
  networking a stale pin means no listener at all (`disconnected`, 0 DHT nodes).
  It is now pinned deliberately to `wg0-mullvad` — see VPN above.
- The config tree may show as `nobody:nobody` on the host. That is expected for these rootless LinuxServer containers because the app user is UID/GID `1000:1000` inside Podman's user namespace; the host user is not in that group, so edit those files from inside the container.
- `/home/luke/data/torrents/incomplete` has Btrfs NOCOW enabled for newly-created partial download files.
- `/home/luke/data` is mapped for the LinuxServer container user and may show as `nobody:nobody` on the host.

## VPN

Everything in the stack egresses through Mullvad: `ip rule` 5209 sends every
unmarked packet to table 1836018789 whose default is `dev wg0-mullvad`, while
LAN/connected routes stay direct, so Jellyfin streaming and the WebUIs never
leave the LAN. Verified from inside the containers: egress IP `103.120.6.175`
(`au-syd-wg-302`), and binding a socket to `enp38s0` cannot reach the internet
at all. `sing-box-bypass` marks its own traffic `0x6d6f6c65` to escape the tunnel
deliberately.

- qBittorrent pins `current_network_interface=wg0-mullvad`, so every torrent
  socket (TCP, uTP, DHT) is bound to the tunnel address — a VPN drop stops
  torrenting instead of falling back to the ISP path. Verify with
  `ss -tn | grep 6881`: local addresses must read `10.152.246.234%wg0-mullvad`.
- Mullvad lockdown mode is **off**, so if the daemon or its interface vanishes,
  unmarked traffic falls through to the LAN default route. For a system-wide kill
  switch: `mullvad lockdown-mode set on` (LAN sharing stays allowed per
  `mullvad lan get`, but it also blocks the sing-box bypass path while
  disconnected).

## yarr (fleet MCP server)

`media-stack-yarr.container` runs `ghcr.io/dinglebear-ai/yarr:2.2.0` — one MCP
tool and one CLI over Sonarr, Radarr, Prowlarr, qBittorrent and Jellyfin.

- Upstream credentials: the `*arr` API keys from each app's `config.xml`, the
  Jellyfin API key, and the qBittorrent WebUI login (`pass qbittorrent`).

- Config and secrets: `/home/luke/.yarr/.env` (mode 0600), bind-mounted at `/data`.
- Transport: MCP over HTTP on `127.0.0.1:40070/mcp`, bearer token in `.env`;
  `/health`, `/ready`, `/status`, `/metrics` are unauthenticated probes.
- `UserNS=keep-id` keeps the image's numeric 1000:1000 user matched to `luke`,
  which is what makes the `/data` bind mount writable.
- yarr never detects Podman as a container (it only checks `/.dockerenv`), so the
  unit sets `HOME=/data` and `.env` sets `YARR_HOME=/data`; without them it reads
  `/home/nonroot/.yarr` and exits with a permission error.

```sh
systemctl --user status media-stack-yarr.service
podman exec yarr /usr/local/bin/yarr doctor --json     # upstream reachability
curl -s http://127.0.0.1:40070/ready
```

Client entry for Claude Code / Codex / Gemini CLI:

```json
{"mcpServers":{"yarr":{"type":"http","url":"http://127.0.0.1:40070/mcp",
  "headers":{"Authorization":"Bearer <YARR_MCP_TOKEN from .yarr/.env>"}}}}
```

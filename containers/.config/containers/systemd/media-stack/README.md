# Media Stack Quadlets

These Quadlet units are the Podman equivalent of `/home/luke/media-stack/docker-compose.yml`.

Reload generated services:

```sh
systemctl --user daemon-reload
```

Start or stop the whole stack:

```sh
systemctl --user start media-stack.target
systemctl --user stop media-stack.target
```

Cut over from the Docker Compose stack:

```sh
cd /home/luke/media-stack
docker-compose down
systemctl --user start media-stack.target
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

- Sonarr and Radarr should use `qbittorrent:8080` for the qBittorrent download client.
- The config tree may show as `nobody:nobody` on the host. That is expected for these rootless LinuxServer containers because the app user is UID/GID `1000:1000` inside Podman's user namespace.
- qBittorrent's WebUI is published on `127.0.0.1:8080`; Sonarr and Radarr reach it over the internal Podman network.
- The torrent listen port is not published from the container. Re-add `6881/tcp` and `6881/udp` only if the VPN has working inbound port forwarding.
- `/home/luke/data/torrents/incomplete` has Btrfs NOCOW enabled for newly-created partial download files.
- `/home/luke/data` is mapped for the LinuxServer container user and may show as `nobody:nobody` on the host. The directories are group-writable/setgid so the host `luke` user can still manage files through its `nobody` group membership.

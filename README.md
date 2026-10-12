# xo-pi-package

Unofficial `.deb` of [Xen Orchestra](https://github.com/vatesfr/xen-orchestra) (built from sources) for Raspberry Pi
(Debian 13 trixie, arm64), with a bundled Node.js.

- Build: `make deb` inside a `debian:trixie` arm64 environment (see `.github/workflows/build.yml`). Output in `out/`.
- Channels: `make deb CHANNEL=stable|latest` (default `stable`) or `make deb VERSION=6.8.2`. The release and its commit
  are resolved by `resolve-xo-ref.sh` from the channel badges in upstream's CHANGELOG (upstream has no release tags).
  Package version is `<xo release>-<revision>`; moving from stable to latest upgrades, the reverse is a downgrade.
- Pins: `versions.env` (channel/version, Node version, package revision).
- Install: `sudo apt install ./xen-orchestra_*_arm64.deb`, then point a reverse proxy at `http://127.0.0.1:8080` (see below) (default login `admin@admin.net` / `admin`).
- Config: `/etc/xo-server/config.toml`; data in `/var/lib/xo-server`; logs via `journalctl -u xen-orchestra`.

## Reverse proxy

xo-server listens on `127.0.0.1:8080` by default (`/etc/xo-server/config.toml`; restart with
`systemctl restart xen-orchestra` after editing). The proxy must forward WebSocket upgrades
(the UI and consoles depend on them), allow large bodies and long timeouts (VM imports, backups).
nginx example:

```nginx
server {
    listen 443 ssl;
    server_name xo.example.com;
    # ssl_certificate / ssl_certificate_key ...

    client_max_body_size 0;
    proxy_request_buffering off;
    proxy_read_timeout 1d;

    location / {
        proxy_pass http://127.0.0.1:8080;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

# xo-pi-package

Unofficial `.deb` of [Xen Orchestra](https://github.com/vatesfr/xen-orchestra) (built from sources) for Raspberry Pi
(Debian 13 trixie, arm64), with a bundled Node.js.

- Build: `make deb` inside a `debian:trixie` arm64 environment (see `.github/workflows/build.yml`). Output in `out/`.
- Pins: `versions.env` (XO ref, Node version, package revision).
- Install: `sudo apt install ./xen-orchestra_*_arm64.deb`, then open `http://<pi>/` (default login `admin@admin.net` / `admin`).
- Config: `/etc/xo-server/config.toml`; data in `/var/lib/xo-server`; logs via `journalctl -u xen-orchestra`.

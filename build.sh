#!/usr/bin/env bash
# Build xen-orchestra_<version>_arm64.deb. Run inside a debian:trixie arm64 environment
# (see .github/workflows/build.yml). Output goes to ./out.
set -euo pipefail

if [ "$(uname -m)" != aarch64 ]; then
  echo "error: must run on arm64 (bundled Node is arm64); use 'make deb-docker' on other hosts" >&2
  exit 1
fi

root=$(cd "$(dirname "$0")" && pwd)
# shellcheck source=versions.env
. "$root/versions.env"

# Flags override versions.env / environment.
while [ $# -gt 0 ]; do
  case $1 in
  --channel) XO_CHANNEL=${2:?}; XO_VERSION=; shift 2 ;;
  --version) XO_VERSION=${2:?}; shift 2 ;;
  *) echo "usage: $0 [--channel stable|latest] [--version X.Y.Z]" >&2; exit 2 ;;
  esac
done

work=$root/work
out=$root/out
pkg=$work/pkgroot
opt=$pkg/opt/xen-orchestra

rm -rf "$work" "$out"
mkdir -p "$work" "$out" "$opt"

# --- Node.js (bundled) ------------------------------------------------------
node_dist=node-v$NODE_VERSION-linux-arm64
base=https://nodejs.org/dist/v$NODE_VERSION
curl -fsSLo "$work/$node_dist.tar.xz" "$base/$node_dist.tar.xz"
curl -fsSLo "$work/SHASUMS256.txt" "$base/SHASUMS256.txt"
(cd "$work" && grep " $node_dist.tar.xz\$" SHASUMS256.txt | sha256sum -c -)
mkdir -p "$opt/node"
tar -xJf "$work/$node_dist.tar.xz" -C "$opt/node" --strip-components=1
export PATH=$opt/node/bin:$PATH

# --- XO sources -------------------------------------------------------------
read -r release commit < <("$root/resolve-xo-ref.sh" "${XO_VERSION:-$XO_CHANNEL}")
git init -q "$work/xo"
cd "$work/xo"
git fetch -q --depth 1 https://github.com/vatesfr/xen-orchestra "$commit"
git checkout -q FETCH_HEAD
version=$release-$PKG_REVISION
echo "Building xen-orchestra $release ($commit) as $version"

# yarn 1 is only needed at build time; install outside the package tree.
npm install --global --prefix "$work/tools" yarn@1.22.22
export PATH=$work/tools/bin:$PATH

yarn install --frozen-lockfile
# Same as upstream `yarn build` minus `build:doc` (docs are not shipped).
TURBO_TELEMETRY_DISABLED=1 yarn turbo run build \
  --filter xo-server --filter 'xo-server-*' --filter xo-web \
  --filter @xen-orchestra/web --filter @xen-orchestra/backup-archive

# Drop dev dependencies; workspace symlinks stay relative so the tree is relocatable.
yarn install --frozen-lockfile --production
yarn cache clean

# --- Stage ------------------------------------------------------------------
rm -rf .git .turbo docs
find . -name '*.map' -not -path '*/node_modules/*' -delete
find . -type d \( -name test -o -name __tests__ \) -prune -exec rm -rf {} +
mv "$work/xo" "$opt/xo"

# npm/corepack are only needed at build time (they installed yarn above).
rm -rf "$opt"/node/{include,share,CHANGELOG.md,README.md} \
  "$opt"/node/lib/node_modules \
  "$opt"/node/bin/{npm,npx,corepack}

cp -a "$root"/packaging/etc "$root"/packaging/lib "$pkg"/
install -Dm644 "$root/packaging/usr/share/doc/xen-orchestra/copyright" \
  "$pkg/usr/share/doc/xen-orchestra/copyright"
install -Dm644 "$opt/xo/AGPL.txt" "$pkg/usr/share/doc/xen-orchestra/AGPL.txt"

mkdir -p "$pkg/DEBIAN"
for f in postinst prerm postrm conffiles; do
  install -m755 "$root/packaging/DEBIAN/$f" "$pkg/DEBIAN/$f"
done
chmod 644 "$pkg/DEBIAN/conffiles"
size=$(du -sk --exclude=DEBIAN "$pkg" | cut -f1)
sed -e "s/@VERSION@/$version/" -e "s/@SIZE@/$size/" \
  "$root/packaging/DEBIAN/control.in" > "$pkg/DEBIAN/control"

dpkg-deb --build --root-owner-group -Zxz "$pkg" "$out/xen-orchestra_${version}_arm64.deb"
ls -lh "$out"

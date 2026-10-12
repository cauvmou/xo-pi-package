#!/usr/bin/env bash
# Resolve an XO release to its commit. Usage: resolve-xo-ref.sh stable|latest|X.Y.Z
# Prints "<version> <commit-sha>".
#
# Upstream has no release tags. A release is the master commit that renames the
# `## **next**` CHANGELOG header to `## **X.Y.Z** (date)`; the channel badges
# (`id="stable"` / `id="latest"`) in the current master CHANGELOG say which release
# each channel points at.
set -euo pipefail

repo=https://github.com/vatesfr/xen-orchestra
arg=${1:?usage: $0 stable|latest|X.Y.Z}

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

git clone -q --filter=blob:none --no-checkout "$repo" "$tmp/xo"
git -C "$tmp/xo" show origin/HEAD:CHANGELOG.md > "$tmp/CHANGELOG.md"

case $arg in
stable|latest)
  # The badge sits under its release header; in one old layout (6.8.0) it sits above.
  version=$(awk -v ch="$arg" '
    /^## \*\*[0-9]/ {
      match($0, /[0-9]+\.[0-9]+(\.[0-9]+)?/); last = substr($0, RSTART, RLENGTH)
      if (pending) { print last; exit }
    }
    index($0, "id=\"" ch "\"") { if (last != "") { print last; exit } else pending = 1 }
  ' "$tmp/CHANGELOG.md")
  ;;
[0-9]*.[0-9]*.[0-9]*) version=$arg ;;
*) echo "error: expected stable, latest or X.Y.Z, got '$arg'" >&2; exit 1 ;;
esac
[ -n "$version" ] || { echo "error: no '$arg' badge found in CHANGELOG.md" >&2; exit 1; }

# Release commits are titled "feat: release X.Y[.Z] (#N)" and put the new version in
# the topmost CHANGELOG header. Walk them newest first, fetching one blob per commit.
commit=
while read -r c; do
  top=$(git -C "$tmp/xo" show "$c:CHANGELOG.md" | grep -m1 -oE '^## \*\*[0-9]+\.[0-9]+(\.[0-9]+)?' | grep -oE '[0-9].*') || true
  if [ "$top" = "$version" ]; then commit=$c; break; fi
done < <(git -C "$tmp/xo" log -i -E --grep='^(feat: )?release ' --format=%H origin/HEAD -- CHANGELOG.md)
[ -n "$commit" ] || { echo "error: no release commit found for $version" >&2; exit 1; }

echo "$version $commit"

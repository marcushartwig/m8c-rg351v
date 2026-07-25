#!/bin/bash
# Installs the SDL2 and libserialport development files needed to build m8c.
#
# Does NOT use apt. ArkOS is Ubuntu 19.10 (eoan), which has been removed from
# both ports.ubuntu.com and old-releases.ubuntu.com - there is no ubuntu-ports
# tree on old-releases at all, so apt cannot resolve anything on a stock image.
# Instead we extract pinned .debs vendored by scripts/fetch-deps.sh.
#
# Extract rather than `dpkg -i`, deliberately: dpkg would demand the full
# dependency chain, which is exactly what we cannot resolve.
set -eu

here=$(cd "$(dirname "$0")/../../.." && pwd)
vendor="$here/vendor"

log() { echo -e "\e[32m$*\e[0m"; }
err() { echo -e "\e[31m$*\e[0m" >&2; }

if [ ! -d "$vendor" ] || [ -z "$(ls -A "$vendor"/*.deb 2>/dev/null)" ]; then
  err "No vendored .debs found in $vendor"
  err "Run scripts/fetch-deps.sh first (needs network), or copy vendor/ from the Mac."
  exit 1
fi

# A compiler is required and cannot be installed from a dead archive. Check
# early and fail with a useful message rather than partway through a build.
missing=""
for tool in gcc make pkg-config; do
  command -v "$tool" >/dev/null || missing="$missing $tool"
done
if [ -n "$missing" ]; then
  err "Missing build tools:$missing"
  err ""
  err "These cannot be apt-installed - the eoan archive is gone. Options:"
  err "  1. Use an ArkOS image that already ships build-essential, or"
  err "  2. Cross-compile on the Mac instead - see docs/plan.md."
  exit 1
fi

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

log "Extracting vendored packages ..."
for deb in "$vendor"/*.deb; do
  echo "  $(basename "$deb")"
  dpkg-deb -x "$deb" "$tmp/root"
done

log "Installing headers and libraries into /usr/local ..."
# /usr/local keeps this separate from ArkOS's own files, so it is trivially
# reversible and cannot clobber the vendor's SDL2.
sudo mkdir -p /usr/local/include /usr/local/lib/pkgconfig
sudo cp -r "$tmp/root/usr/include/"* /usr/local/include/

# Only take libserialport's binaries. SDL2's runtime is deliberately NOT
# installed - ArkOS already ships SDL2 2.28.2 built for the RK3326 display
# stack, and we link against that. We use eoan's 2.0.10 only for its headers,
# which is safe: SDL2 guarantees forward ABI compatibility, and m8c v1.7.10
# references no SDL symbol absent from 2.0.10.
for so in "$tmp"/root/usr/lib/aarch64-linux-gnu/libserialport*; do
  [ -e "$so" ] && sudo cp -P "$so" /usr/local/lib/
done

for pc in "$tmp"/root/usr/lib/aarch64-linux-gnu/pkgconfig/*.pc; do
  [ -e "$pc" ] || continue
  sudo sed -e 's|^prefix=.*|prefix=/usr/local|' \
           -e 's|/usr/lib/aarch64-linux-gnu|/usr/local/lib|g' \
           -e 's|/usr/include|/usr/local/include|g' \
           "$pc" | sudo tee "/usr/local/lib/pkgconfig/$(basename "$pc")" >/dev/null
done

# The linker needs an unversioned libSDL2.so to resolve -lSDL2. ArkOS ships the
# versioned runtime but not always this symlink.
sdl_runtime=$(find /usr/lib -name 'libSDL2-2.0.so.0.*' -print -quit 2>/dev/null || true)
if [ -n "$sdl_runtime" ]; then
  libdir=$(dirname "$sdl_runtime")
  if [ ! -e "$libdir/libSDL2.so" ]; then
    log "Creating libSDL2.so -> $(basename "$sdl_runtime")"
    sudo ln -sf "$(basename "$sdl_runtime")" "$libdir/libSDL2.so"
  fi
else
  err "No libSDL2 runtime found in /usr/lib - is this really ArkOS?"
  exit 1
fi

sudo ldconfig

export PKG_CONFIG_PATH=/usr/local/lib/pkgconfig:${PKG_CONFIG_PATH:-}
log ""
log "sdl2:         $(pkg-config --modversion sdl2 2>/dev/null || echo 'NOT FOUND') (headers)"
log "SDL2 runtime: $(basename "$sdl_runtime")"
log "libserialport: $(pkg-config --modversion libserialport 2>/dev/null || echo 'NOT FOUND')"
log "Finished."

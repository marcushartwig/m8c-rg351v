#!/bin/bash
# Clones and builds m8c on-device, then installs the binary into ports/M8/m8c/.
# Phase 1 targets v1.7.10 - the last SDL2 release. See docs/plan.md.
set -eu

M8C_REF="${M8C_REF:-v1.7.10}"
here=$(cd "$(dirname "$0")/.." && pwd)
src="$here/.src/m8c"

log() { echo -e "\e[32m$*\e[0m"; }

for tool in git make pkg-config gcc; do
  command -v "$tool" >/dev/null || { echo "Missing $tool - run install_build_tools.sh first"; exit 1; }
done

# install_build_tools.sh stages headers and .pc files under /usr/local.
export PKG_CONFIG_PATH=/usr/local/lib/pkgconfig:${PKG_CONFIG_PATH:-}

pkg-config --exists sdl2 || { echo "sdl2 dev headers missing - run install_build_tools.sh"; exit 1; }
pkg-config --exists libserialport || { echo "libserialport dev headers missing"; exit 1; }

if [ ! -d "$src/.git" ]; then
  log "Cloning m8c ..."
  mkdir -p "$(dirname "$src")"
  git clone https://github.com/laamaa/m8c.git "$src"
fi

log "Checking out $M8C_REF ..."
git -C "$src" fetch --tags --quiet
git -C "$src" checkout --quiet "$M8C_REF"
git -C "$src" clean -qfdx

log "Building (this takes a few minutes on the RK3326) ..."
make -C "$src" -j"$(nproc)"

log "Installing to $here/m8c/ ..."
install -m 755 "$src/m8c" "$here/m8c/m8c"
install -m 644 "$src/gamecontrollerdb.txt" "$here/m8c/gamecontrollerdb.txt"

log "Built m8c $M8C_REF:"
file "$here/m8c/m8c" || true
ldd "$here/m8c/m8c" | grep -E 'SDL|serialport' || true
log "Finished."

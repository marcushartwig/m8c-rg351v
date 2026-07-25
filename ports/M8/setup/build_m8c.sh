#!/bin/bash
# Clones and builds m8c on-device, then installs the binary into ports/M8/m8c/.
# Phase 1 targets v1.7.10 - the last SDL2 release. See docs/plan.md.
set -eu

M8C_REF="${M8C_REF:-v1.7.10}"

# The commit v1.7.10 pointed at when this was written. Upstream uses a
# lightweight tag, which can be moved or recreated, so a tag name alone is not a
# reproducible pin - verify what we actually got. Only checked for the default
# ref; overriding M8C_REF skips it.
M8C_COMMIT="3b59f68a2a9a66129567872251dee58b6cbbf131"
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
git -C "$src" fetch --tags --force --quiet
git -C "$src" checkout --quiet "$M8C_REF"
git -C "$src" clean -qfdx

got=$(git -C "$src" rev-parse HEAD)
if [ "$M8C_REF" = "v1.7.10" ] && [ "$got" != "$M8C_COMMIT" ]; then
  echo "" >&2
  echo "REFUSING TO BUILD: v1.7.10 resolved to an unexpected commit." >&2
  echo "  expected $M8C_COMMIT" >&2
  echo "  got      $got" >&2
  echo "The upstream tag has moved since this was pinned. Review the changes" >&2
  echo "before trusting the result, then update M8C_COMMIT if it is legitimate." >&2
  exit 1
fi
log "Commit $got"

log "Building (this takes a few minutes on the RK3326) ..."
make -C "$src" -j"$(nproc)"

log "Installing to $here/m8c/ ..."
install -m 755 "$src/m8c" "$here/m8c/m8c"
install -m 644 "$src/gamecontrollerdb.txt" "$here/m8c/gamecontrollerdb.txt"

log "Built m8c $M8C_REF:"
file "$here/m8c/m8c" || true
ldd "$here/m8c/m8c" | grep -E 'SDL|serialport' || true
log "Finished."

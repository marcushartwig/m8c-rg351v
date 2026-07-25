#!/bin/bash
# Installs the toolchain needed to compile m8c on-device.
# Must be online. Run once, from a terminal so you can see the output.
set -u

log() { echo -e "\e[32m$*\e[0m"; }
err() { echo -e "\e[31m$*\e[0m" >&2; }

# Ubuntu 19.10 (eoan) is long EOL; its packages moved to old-releases.
# ArkOS images vary in whether this has been fixed, so repair it if needed.
if grep -rqs 'ports.ubuntu.com' /etc/apt/sources.list /etc/apt/sources.list.d/ 2>/dev/null; then
  if ! sudo apt-get update -qq 2>/dev/null; then
    log "apt failed against ports.ubuntu.com - repointing eoan to old-releases"
    sudo cp -n /etc/apt/sources.list /etc/apt/sources.list.bak
    sudo sed -i 's|ports.ubuntu.com/ubuntu-ports|old-releases.ubuntu.com/ubuntu-ports|g' \
      /etc/apt/sources.list
  fi
fi

log "Updating package lists ..."
sudo apt-get update --assume-yes || err "apt update reported errors; continuing"

log "Installing build tools and headers ..."
sudo apt-get install --assume-yes --reinstall \
  build-essential pkg-config git \
  libsdl2-dev libserialport-dev \
  libc6-dev linux-libc-dev || { err "Package install failed."; exit 1; }

# ArkOS ships SDL2 2.28.2 but the unversioned .so symlink the linker needs
# is not always present. Create it if it is missing.
libdir=$(dirname "$(find /usr/lib -name 'libSDL2-2.0.so.0.*' -print -quit)" 2>/dev/null)
if [ -n "$libdir" ] && [ ! -e "$libdir/libSDL2.so" ]; then
  target=$(basename "$(find /usr/lib -name 'libSDL2-2.0.so.0.*' -print -quit)")
  log "Creating missing libSDL2.so -> $target"
  sudo ln -sf "$target" "$libdir/libSDL2.so"
fi

log "SDL2 version: $(pkg-config --modversion sdl2 2>/dev/null || echo 'NOT FOUND')"
log "libserialport: $(pkg-config --modversion libserialport 2>/dev/null || echo 'NOT FOUND')"
log "Finished."

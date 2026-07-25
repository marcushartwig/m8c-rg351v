#!/bin/bash
# Runtime setup: grants serial access to the Teensy.
#
# No apt here - see install_build_tools.sh for why. The libserialport runtime
# is installed from the vendored .deb by that script; this only handles the
# permissions side, which is all a run-only device needs.
set -eu

log() { echo -e "\e[32m$*\e[0m"; }

# m8c talks to the Teensy over /dev/ttyACM*, owned by group dialout.
if id -nG "$USER" | tr ' ' '\n' | grep -qx dialout; then
  log "$USER is already in the dialout group."
else
  log "Adding $USER to the dialout group ..."
  sudo usermod -aG dialout "$USER"
  log "Group changed - you must REBOOT before this takes effect."
fi

# cdc-acm binds USB CDC serial devices like the Teensy.
if ! lsmod | grep -q '^cdc_acm'; then
  log "Loading cdc-acm ..."
  sudo modprobe cdc-acm || log "Could not modprobe cdc-acm (may be built into the kernel)"
fi

log "Finished."

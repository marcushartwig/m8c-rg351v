#!/bin/bash
# Runtime setup: installs the libserialport runtime and grants serial access.
# Run this once, then REBOOT so the group change takes effect.
set -u

log() { echo -e "\e[32m$*\e[0m"; }

log "Installing runtime dependencies ..."
sudo apt-get update --assume-yes
sudo apt-get install --assume-yes libserialport0 alsa-utils

# m8c talks to the Teensy over /dev/ttyACM*, which is owned by group dialout.
log "Adding $USER to the dialout group ..."
sudo adduser "$USER" dialout

log "Finished. Reboot the device before launching M8."

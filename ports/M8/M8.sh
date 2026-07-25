#!/bin/bash
# Launcher for m8c on the RG351V (ArkOS).
# Routes the Teensy's USB audio to the device speakers via alsaloop, runs m8c,
# then cleans up. Governor defaults to powersave, which reduces audio crackle;
# set GOVERNOR=performance for the alternate profile.
set -u

GOVERNOR="${GOVERNOR:-powersave}"
IDLE_MS="${IDLE_MS:-25}"

here=$(cd "$(dirname "$0")" && pwd)
cd "$here"

# Seed our tuned config on first run, then keep the user's copy authoritative.
config="$HOME/.local/share/m8c/config.ini"
if [ ! -f "$config" ] && [ -f "$here/config.ini" ]; then
  mkdir -p "$(dirname "$config")"
  cp "$here/config.ini" "$config"
fi
[ -f "$config" ] && sed -i "/^idle_ms=/s/=.*/=$IDLE_MS/" "$config"

echo "$GOVERNOR" | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor >/dev/null

# Find the Teensy's capture card by name rather than assuming a card number -
# plugging in a MIDI device shifts the numbering around.
find_m8_card() {
  awk '/^ *[0-9]+ \[/ { card=$1 } /M8|Teensy/ { if (card != "") { print card; exit } }' /proc/asound/cards
}

start_loopback() {
  local card
  for _ in $(seq 1 30); do
    card=$(find_m8_card)
    if [ -n "$card" ]; then
      alsaloop -P hw:0,0 -C "hw:$card,0" -t 200000 -A 5 --rate 44100 --sync=0 -T -1 -d
      return
    fi
    sleep 1
  done
}

start_loopback &
loopback_pid=$!

./m8c/m8c

kill "$loopback_pid" 2>/dev/null
pkill alsaloop

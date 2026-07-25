#!/bin/bash
# Downloads the pinned aarch64 .deb dependencies into vendor/.
#
# Why not apt: ArkOS is Ubuntu 19.10 (eoan), which is EOL and has been removed
# from BOTH ports.ubuntu.com and old-releases.ubuntu.com - old-releases carries
# no ubuntu-ports tree at all. So `apt-get install` cannot work on a stock ArkOS
# image today. Launchpad, however, still serves the individual binaries even
# though they are marked Obsolete. We pin exact versions and verify checksums.
#
# Run this on the Mac (then copy vendor/ to the SD card) or on the device.
set -eu

here=$(cd "$(dirname "$0")/.." && pwd)
dest="$here/vendor"
base="https://launchpad.net/ubuntu/+archive/primary/+files"

# package .deb : sha256
read -r -d '' PINS <<'EOF' || true
libserialport0_0.1.1-3_arm64.deb 6d944cf91fd8fdb9acf4da45907a706032bc71a30d11a08417d502a88ff2a9ef
libserialport-dev_0.1.1-3_arm64.deb 6470f01a0152d21265c5fb119f49b2d296a3fb72dc6b456a1ce239c359f93d8e
libsdl2-2.0-0_2.0.10+dfsg1-1ubuntu1_arm64.deb 34f06694f13bbee317b89be868768e8fd5b030287431a630881f45ff99dc9264
libsdl2-dev_2.0.10+dfsg1-1ubuntu1_arm64.deb 9eb97797c392b68449045d814f8763ca984853abefff94ababdc72270b7d65ea
EOF

mkdir -p "$dest"

sha256_of() {
  if command -v sha256sum >/dev/null; then sha256sum "$1" | cut -d' ' -f1
  else shasum -a 256 "$1" | cut -d' ' -f1; fi
}

echo "$PINS" | while read -r deb sum; do
  [ -z "$deb" ] && continue
  out="$dest/$deb"
  if [ -f "$out" ] && [ "$(sha256_of "$out")" = "$sum" ]; then
    echo "ok (cached)  $deb"
    continue
  fi
  echo "fetching     $deb"
  curl -fsSL -o "$out" "$base/$deb"
  got=$(sha256_of "$out")
  if [ "$got" != "$sum" ]; then
    echo "CHECKSUM MISMATCH for $deb" >&2
    echo "  expected $sum" >&2
    echo "  got      $got" >&2
    rm -f "$out"
    exit 1
  fi
  echo "ok           $deb"
done

echo
echo "Vendored into $dest"
ls -la "$dest"

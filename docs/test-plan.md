# Baseline test plan (ArkOS)

Work through this on the device and record the answers — step 3 in particular
decides whether we build on-device or switch to cross-compiling.

## 0. Get an image

ArkOS was archived 2025-12-30 and its GitHub releases carry **zero assets** —
the images have always been hosted on Google Drive / Mediafire / MEGA, linked
from the [wiki](https://github.com/christianhaitian/arkos/wiki), which is still
readable. Those third-party links are now unmaintained, so grab the image and
**keep a local copy**; there is no guarantee it stays up.

- [ ] image downloaded and archived somewhere safe
- [ ] note the version string

## 1. Confirm architecture and glibc

```bash
uname -m                 # expect aarch64
ldd --version | head -1  # expect 2.30 (Ubuntu 19.10 / eoan)
lsb_release -a 2>/dev/null || cat /etc/os-release
```

- [ ] `aarch64`
- [ ] glibc version: ______

If glibc is **older** than 2.30, tell me — it changes the cross-compile base
image (we would need something older than Debian Buster).

## 2. Confirm the SDL2 runtime

We link against ArkOS's own SDL2 rather than shipping one, because the vendor
build is configured for the RK3326 display stack.

```bash
find /usr/lib -name 'libSDL2*'
```

- [ ] a `libSDL2-2.0.so.0.28xx.x` exists → confirms the expected 2.28.x
- [ ] version found: ______

## 3. THE DECIDING QUESTION — is there a compiler?

```bash
which gcc make pkg-config git
gcc --version 2>/dev/null | head -1
```

This matters because **apt cannot install one**. Ubuntu 19.10 has been removed
from `ports.ubuntu.com` *and* from `old-releases.ubuntu.com` — the latter has no
`ubuntu-ports` tree at all, only `ubuntu/` (x86). Verified 2026-07-25.

- [ ] **gcc present** → on-device build works. Continue to step 4.
- [ ] **gcc absent** → stop. We cross-compile on the Mac instead; pulling
      build-essential's full dependency chain from Launchpad by hand is not
      worth it. See [plan.md](plan.md).

## 4. Vendored dependencies

On the Mac, run `scripts/fetch-deps.sh`, then copy the whole port folder
(including `vendor/`) to `/roms/ports/M8` on the SD card.

These are pinned eoan `.deb`s pulled from Launchpad, which still serves them
despite their `Obsolete` status. Checksums are verified on download.

```bash
ls /roms/ports/M8/../../vendor/    # adjust to wherever you copied it
./setup/install_build_tools.sh
```

- [ ] extraction succeeded
- [ ] `pkg-config --modversion sdl2` reports 2.0.10 (headers — expected)
- [ ] `pkg-config --modversion libserialport` reports 0.1.1

The 2.0.10-headers-against-2.28.2-runtime mismatch is intentional and safe; see
[plan.md](plan.md) for the symbol-level verification.

## 5. Serial access

```bash
./setup/setup.sh
# then REBOOT
id -nG | tr ' ' '\n' | grep dialout
```

- [ ] `dialout` present after reboot

## 6. Teensy enumeration

Plug the Teensy 4.1 into the RG351V's USB-C OTG port via a USB-C→USB-A adapter.

```bash
dmesg | grep -iE 'cdc_acm|ttyACM'
ls -l /dev/ttyACM*
```

- [ ] `/dev/ttyACM0` appears
- [ ] readable as your user (not just root)

## 7. Build

```bash
./setup/build_m8c.sh
```

- [ ] compiles without errors
- [ ] `ldd m8c/m8c` shows `libSDL2-2.0.so.0` and `libserialport.so.0`
- [ ] note the wall-clock build time: ______

## 8. Run

```bash
./M8.sh
```

- [ ] M8 screen renders
- [ ] fills the 640×480 panel, pixel-crisp (exact 2× of 320×240)
- [ ] d-pad and buttons behave — if not, it is almost certainly a missing
      `gamecontrollerdb` entry rather than `config.ini`
- [ ] audio audible via alsaloop
- [ ] **listen for crackle**. If present, try `GOVERNOR=performance ./M8.sh`,
      then `IDLE_MS=10`, then raising `audio_buffer_size` in config.ini.

## What the results decide

- **All good** → tune config, then consider phase 2 (m8c 2.2.4 + SDL3), which
  on ArkOS means cross-building and bundling SDL3 ourselves.
- **No compiler** → cross-compile phase 1 on the Mac. Same vendored headers,
  Debian Buster arm64 container, native speed on the M1.
- **Audio crackles badly** → this is the known weak point of the platform;
  ROCKNIX (see the sibling repo) uses PipeWire and may handle it better.

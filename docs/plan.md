# Plan

Goal: run the latest m8c (v2.2.4) on an RG351V running ArkOS, as the screen and
controller for an M8 Headless on a Teensy 4.1.

## The core problem

m8c changed its graphics dependency mid-2025:

| m8c version | Released | SDL |
| --- | --- | --- |
| ≤ v1.7.10 | 2025-03-03 | SDL2 |
| v2.0.0 → v2.2.4 (HEAD) | 2025-08-25 → 2026-01 | **SDL3, required** |

ArkOS for the RG351V is aarch64 on an **Ubuntu 19.10 (eoan)** base: glibc 2.30,
cmake 3.13, EOL apt archives. There is no SDL3 package and there will not be one.
So targeting current m8c means building and shipping SDL3 ourselves.

Two things make that easier than it sounds:

- m8c's plain `Makefile` needs only `pkg-config sdl3 libserialport` — no cmake.
  That sidesteps CMakeLists.txt's `cmake_minimum_required(VERSION 3.20)`.
- Kitware publishes `cmake-*-linux-aarch64.tar.gz`, which covers building SDL3
  itself if we ever need to do it on-device.

Upstream publishes **no ARM Linux binaries** (v2.2.3 assets are x86_64 AppImage,
macOS, Windows only), so there is nothing to shortcut with.

## The apt archive is gone (verified 2026-07-25)

ArkOS was archived 2025-12-30. More consequentially for us, **Ubuntu 19.10 ARM
packages no longer exist on any official mirror**:

| URL | result |
| --- | --- |
| `ports.ubuntu.com/ubuntu-ports/dists/eoan/Release` | 404 |
| `old-releases.ubuntu.com/ubuntu-ports/...` | 404 — no `ubuntu-ports` tree at all |
| `old-releases.ubuntu.com/` | only `releases/` and `ubuntu/` (x86) |

So `apt-get install libsdl2-dev libserialport-dev` cannot work on a stock ArkOS
image today. This breaks jasonporritt's `_setup_build_tools.sh`, ArkOS's own
`Headers/install_headers.sh` (which does `apt -t eoan install`), and the
`old-releases` repoint originally written here.

**Rescue: Launchpad still serves the individual binaries.** They are marked
`Obsolete`, but the files download fine from
`launchpad.net/ubuntu/+archive/primary/+files/`. `scripts/fetch-deps.sh` pins
four packages with sha256 verification:

```
libserialport0      0.1.1-3
libserialport-dev   0.1.1-3
libsdl2-2.0-0       2.0.10+dfsg1-1ubuntu1
libsdl2-dev         2.0.10+dfsg1-1ubuntu1
```

`install_build_tools.sh` extracts these into `/usr/local` with `dpkg-deb -x`
rather than `dpkg -i`, because dpkg would demand a dependency chain we cannot
resolve.

### Why 2.0.10 headers against a 2.28.2 runtime is safe

We install eoan's SDL2 **headers** but deliberately do *not* install its runtime
— ArkOS ships SDL2 2.28.2 built for the RK3326 display stack, and that is what
we link against. SDL2 guarantees forward ABI compatibility, so this works
provided m8c uses no symbol newer than 2.0.10.

Verified rather than assumed: extracting every `SDL_*` identifier m8c v1.7.10
references (192 of them) and diffing against every identifier declared in the
2.0.10 headers (2277) leaves exactly three, all benign:

- `SDL_inprint` — a comment referencing the upstream bitmap-font project
- `SDL_AndroidSendMessage` — inside `#ifdef __ANDROID__` (`render.c:210`)
- `SDL_strtokr` — in `usb.c`, whose entire body is `#ifdef USE_LIBUSB`
  (lines 6–363), never defined in the default libserialport build

## Verified on hardware, 2026-07-25

SSH'd into the actual device. Several assumptions above turned out to be wrong,
and the outcome is much better than planned.

| | expected | actual |
| --- | --- | --- |
| base | Ubuntu 19.10 eoan | **confirmed** — glibc 2.30, kernel 4.4.189, aarch64 |
| compiler | unknown, feared absent | **gcc 9.2.1**, make 4.2.1, pkg-config, git all present |
| SDL2 dev | absent, needed vendoring | **already installed** — headers + `sdl2.pc` |
| SDL2 version (aarch64) | 2.28.2 | **2.0.10** — see below |
| libserialport dev | absent, needed vendoring | **already installed** — 0.1.1 |
| video | unclear | SDL2 has **KMSDRM**, no X server, `DISPLAY` empty |
| `dialout` group | needed adding | `ark` is already a member |

**The SDL2 version claim was wrong.** ArkOS's `install_headers.sh` symlinks
`libSDL2-2.0.so.0.2800.2`, which I read as "ArkOS ships 2.28.2". It does — but
in `/usr/lib/arm-linux-gnueabihf`, the **armhf** tree used by 32-bit emulator
cores. The **aarch64** tree we actually compile against has stock eoan
**2.0.10**.

That makes the symbol verification above load-bearing rather than academic: we
compile *and* link against 2.0.10, so "does m8c v1.7.10 use anything newer than
2.0.10" was exactly the right question. It does not, and the build confirms it.

**The vendored .deb path was not needed on this device**, since the dev packages
were already installed. It is kept as a fallback for a fresh image, and
`install_build_tools.sh` now short-circuits when pkg-config is already satisfied.

### Build result

```
make -j4   →   real 0m9.878s
```

Clean build, no errors. `usb.c` compiled to an empty object exactly as the
`#ifdef USE_LIBUSB` analysis predicted. Output: 72712-byte aarch64 PIE
executable linking `libSDL2-2.0.so.0` and `libserialport.so.0`, all resolved.

Smoke test found the hardware:

```
INFO: Found 573 game controller mappings
INFO: Found M8 in /dev/ttyACM0.
INFO: Opening port.
INFO: Enabling and resetting M8 display
```

Installed to `/roms/ports/M8/_m8c/m8c`, replacing a Nov 2022 build (55616 bytes,
roughly v1.4 era). Previous binary preserved as `m8c.bak-2022`.
`gamecontrollerdb.txt` also refreshed (261 KB → 507 KB).

### Confirmed working on hardware

Display, audio and controls all verified working by the user on 2026-07-25.
Phase 1 is done.

**`ERROR: Could not lock GBM surface front buffer` is benign.** It appears once
at startup on the KMSDRM/GBM path and rendering is fine afterwards. Do not chase
it, and do not "fix" it by setting `use_gpu=false` — the GPU path works.

One real limitation: SDL 2.0.10 on this device does not recognise EVDEV
keycodes 309/310 (`BTN_TL2`/`BTN_TR2`, i.e. L2/R2), logging "The key you just
pressed is not recognized by SDL" for each press. Everything else maps. If a
binding on L2/R2 is ever needed, that is where to look.

### Running it over SSH for testing

m8c needs DRM master and EmulationStation holds it, so a remote test means
taking the display and giving it back. `emulationstation.service` is `enabled`,
so a reboot always restores the UI if something goes wrong.

```sh
sudo systemctl stop emulationstation
cd /roms/ports/M8 && setsid nohup ./M8.sh > /tmp/m8c.log 2>&1 < /dev/null &
# ... test ...
pkill m8c; pkill alsaloop
sudo systemctl start emulationstation
```

Normal use does not need any of this — launch **M8** from the Ports menu, which
handles the handover itself.

### Cross-compiling: no longer needed

The concern was that `gcc` cannot be apt-installed and hand-resolving
build-essential from Launchpad would not be worth it. Moot — the device ships
gcc 9.2.1, and a full build takes ten seconds. The Mac-side cross-build
(Debian Buster arm64 in Apple's `container`) is shelved unless a future image
turns out to lack a toolchain.

## Phase 1 — v1.7.10, built on-device

Proves the whole chain: USB serial to the Teensy, audio routing, gamepad
mapping, and display. Builds against ArkOS's **own SDL2 2.28.2**, which already
has the RK3326 Mali/KMSDRM backends configured correctly — cross-building this
phase against a generic Debian SDL2 risks a black screen for reasons unrelated
to our code. ~34 source files, a few minutes on the A35.

1. `setup/install_build_tools.sh` — toolchain + headers (needs network)
2. `setup/build_m8c.sh` — clone, checkout v1.7.10, make, install to `m8c/`
3. `setup/setup.sh` — runtime deps + dialout group, then reboot
4. `M8.sh` — launch

## Phase 2 — v2.2.4 with bundled SDL3, cross-built on the Mac

Build environment: Apple's `container` 1.1.0 on macOS 26 / Apple Silicon. A Linux
**aarch64** container runs natively on the M1 Pro — no QEMU, no slow
cross-toolchain. Base image should have glibc ≤ 2.30 to match the device;
Debian Buster arm64 is 2.28, comfortably below.

Ship SDL3 as a bundled `.so` next to the binary and set `LD_LIBRARY_PATH` in the
launcher. This is the pattern `stappa/m8c_rg35xx` uses with its vendored `lib/`.

Open questions for phase 2:
- SDL3 needs to come up on **KMSDRM**; SDL2's fbdev path is not available. Needs
  libdrm/libgbm headers at build time.
- m8c calls `SDL_CreateWindowAndRenderer` at 2× the 320×240 texture = 640×480,
  an exact match for the RG351V panel. No scaling or GPU pressure expected.
- Audio backend moved to `src/backends/audio_sdl.c`; confirm it behaves with
  the alsaloop routing before assuming phase 1's audio setup carries over.

## Prior art

- [jasonporritt/rg351_m8c](https://github.com/jasonporritt/rg351_m8c) — ArkOS
  ports package for RG351, last touched 2023-03. Not a fork of m8c; it builds
  on-device via apt. **No top-level LICENSE**, so our scripts are written fresh
  and this is credited as prior art, not copied.
- [stappa/m8c_rg35xx](https://github.com/stappa/m8c_rg35xx) — Docker
  cross-compile for RG35XX/Batocera, pinned to m8c `514e71a`, SDL2. The
  toolchain image targets a different SoC and OS, so only the pattern transfers.
- [laamaa/m8c](https://github.com/laamaa/m8c) — upstream, MIT.

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

# m8c-rg351v

Turn an **Anbernic RG351V** running **ArkOS** into the screen and controller for
a **Dirtywave M8 Headless** on a Teensy 4.1.

This packages [laamaa/m8c](https://github.com/laamaa/m8c) (MIT) as an ArkOS port,
with launcher scripts, audio routing and build tooling.

The RG351V's 640×480 panel is an exact 2× integer scale of the M8's 320×240
display, so the image is pixel-perfect with no filtering.

## Status

Phase 1 (m8c **v1.7.10**, SDL2, built on-device) — **done and confirmed working
on hardware 2026-07-25.** Display, audio and controls all verified. Compiles in
~10s on the device, replacing a Nov 2022 binary (~v1.4 era).

Phase 2 (m8c **v2.2.4** with bundled SDL3) — not started, and harder here than
on ROCKNIX: the aarch64 SDL2 is stock eoan 2.0.10, so SDL3 would have to be
built from source.

The device turned out to already have gcc 9.2.1, SDL2 dev and libserialport dev
installed, so the vendored-`.deb` machinery below was not needed — it is kept as
a fallback for a fresh image. Verified details in [docs/plan.md](docs/plan.md).

See [docs/plan.md](docs/plan.md) for why it's split this way; the short version
is that m8c v2.0.0+ requires SDL3, and ArkOS is an Ubuntu 19.10 base that will
never have an SDL3 package.

## Requirements

- RG351V with [ArkOS](https://github.com/christianhaitian/arkos/wiki) installed
- Teensy 4.1 with [M8 Headless firmware](https://github.com/DirtyWave/M8Docs/blob/main/docs/M8HeadlessSetup.md)
- USB-C to USB-A adapter for the RG351V's OTG port
- Network on the device for the one-time setup (not needed to run m8c)

## Heads-up: ArkOS's package archive no longer exists

Ubuntu 19.10 ARM packages have been removed from `ports.ubuntu.com` **and** from
`old-releases.ubuntu.com` (which carries no `ubuntu-ports` tree at all). Verified
2026-07-25. So `apt-get install` cannot work on a stock ArkOS image, which breaks
the setup scripts in every existing RG351V m8c guide, including ArkOS's own.

The workaround here: **Launchpad still serves the individual `.deb`s** despite
marking them `Obsolete`. `scripts/fetch-deps.sh` pins four packages with sha256
verification, and `install_build_tools.sh` extracts them into `/usr/local`
instead of going through apt. Details in [docs/plan.md](docs/plan.md).

## Install

1. On the Mac: `./scripts/fetch-deps.sh` — downloads the pinned dependencies
   into `vendor/`.
2. Copy `ports/M8` **and** `vendor/` to the device's SD card.
3. Boot the device. The scripts appear under **Ports**.
4. Run `setup/setup.sh` — adds you to `dialout`. Then **reboot**.
5. Run `setup/install_build_tools.sh`, then `setup/build_m8c.sh`.
6. Launch with `M8.sh`.

Work through [docs/test-plan.md](docs/test-plan.md) as you go — step 3 checks
whether the device has a compiler at all, which decides whether this on-device
route works or we cross-compile on the Mac instead.

Building on-device is deliberate for phase 1: ArkOS ships **SDL2 2.28.2** with
the RK3326 Mali/KMSDRM backends already configured, and linking against that is
far more reliable than cross-building against a generic SDL2. We use eoan's
2.0.10 headers only — safe, and verified symbol-by-symbol in
[docs/plan.md](docs/plan.md).

To build a different m8c revision:

```bash
M8C_REF=v1.7.9 ./setup/build_m8c.sh
```

## Layout

```
scripts/fetch-deps.sh  pins and downloads the .deb dependencies (run on the Mac)
vendor/                fetched .debs, gitignored
ports/M8/              → /roms/ports/M8 on the device
  M8.sh                  launcher: config seeding, audio routing, governor
  config.ini             tuned m8c config for the RG351V (untested)
  m8c/                   built binary lands here
  setup/                 setup and on-device build scripts
build/                 phase 2: containerised SDL3 cross-build (not yet written)
docs/plan.md           the plan, the dead-archive problem, the SDL2→SDL3 problem
docs/test-plan.md      run this on the device, in order
```

## Credits

- [laamaa/m8c](https://github.com/laamaa/m8c) — the client this packages, MIT.
- [jasonporritt/rg351_m8c](https://github.com/jasonporritt/rg351_m8c) — prior art
  for the ArkOS ports layout and audio routing approach. It carries no top-level
  licence, so the scripts here are written fresh rather than copied.
- [stappa/m8c_rg35xx](https://github.com/stappa/m8c_rg35xx) — prior art for the
  containerised cross-build and bundled-library packaging.

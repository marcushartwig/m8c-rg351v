# m8c-rg351v

Turn an **Anbernic RG351V** running **ArkOS** into the screen and controller for
a **Dirtywave M8 Headless** on a Teensy 4.1.

This packages [laamaa/m8c](https://github.com/laamaa/m8c) (MIT) as an ArkOS port,
with launcher scripts, audio routing and build tooling.

The RG351V's 640×480 panel is an exact 2× integer scale of the M8's 320×240
display, so the image is pixel-perfect with no filtering.

## Status

Phase 1 (m8c **v1.7.10**, SDL2, built on-device) — scaffolded, not yet run on
hardware. Phase 2 (m8c **v2.2.4** with bundled SDL3, cross-built) — not started.

See [docs/plan.md](docs/plan.md) for why it's split this way; the short version
is that m8c v2.0.0+ requires SDL3, and ArkOS is an Ubuntu 19.10 base that will
never have an SDL3 package.

## Requirements

- RG351V with [ArkOS](https://github.com/christianhaitian/arkos/wiki) installed
- Teensy 4.1 with [M8 Headless firmware](https://github.com/DirtyWave/M8Docs/blob/main/docs/M8HeadlessSetup.md)
- USB-C to USB-A adapter for the RG351V's OTG port
- Network on the device for the one-time setup (not needed to run m8c)

## Install

1. Copy `ports/M8` to `/roms/ports/M8` on the device's SD card.
2. Boot the device. The scripts appear under **Ports**.
3. Run `setup/setup.sh` — installs `libserialport0` and adds you to `dialout`.
4. **Reboot**, so the group change takes effect.
5. Run `setup/install_build_tools.sh`, then `setup/build_m8c.sh` to compile the
   binary into `ports/M8/m8c/`.
6. Launch with `M8.sh`.

Building on-device is deliberate for phase 1: ArkOS ships **SDL2 2.28.2** with
the RK3326 Mali/KMSDRM backends already configured, and linking against that is
far more reliable than cross-building against a generic SDL2.

To build a different m8c revision:

```bash
M8C_REF=v1.7.9 ./setup/build_m8c.sh
```

## Layout

```
ports/M8/          → /roms/ports/M8 on the device
  M8.sh              launcher: audio routing, cpu governor, run m8c
  m8c/               built binary lands here
  setup/             one-time setup and on-device build scripts
build/             phase 2: containerised SDL3 cross-build (not yet written)
docs/plan.md       the plan, and the SDL2→SDL3 problem
```

## Credits

- [laamaa/m8c](https://github.com/laamaa/m8c) — the client this packages, MIT.
- [jasonporritt/rg351_m8c](https://github.com/jasonporritt/rg351_m8c) — prior art
  for the ArkOS ports layout and audio routing approach. It carries no top-level
  licence, so the scripts here are written fresh rather than copied.
- [stappa/m8c_rg35xx](https://github.com/stappa/m8c_rg35xx) — prior art for the
  containerised cross-build and bundled-library packaging.

# Prebuilt binary

Archived copy of the working m8c build, so it can be restored without
recompiling.

| | |
| --- | --- |
| file | `m8c-v1.7.10-aarch64-arkos` |
| upstream | [laamaa/m8c](https://github.com/laamaa/m8c) tag `v1.7.10` (2025-03-03) |
| built | 2026-07-25, on the device, `gcc 9.2.1` (Ubuntu 19.10), `make -j4`, ~10s |
| target | aarch64 ELF PIE, ArkOS / Ubuntu 19.10, glibc 2.30 |
| size | 72712 bytes |
| sha256 | `2fa9626a84673d54751f118c0f6e4aa3806ca2a78fcaf2ad53c09c4784d2782f` |

Links against `libSDL2-2.0.so.0` (ArkOS ships **2.0.10** in the aarch64 tree) and
`libserialport.so.0` (0.1.1). Both were already present on the device.

`gamecontrollerdb.txt` is the copy shipped with v1.7.10 — 507570 bytes,
sha256 `9ac0ae58a9e7248a01aff469db2215ac85689ef7fe2385f20b8e142d511bcd9a`.
It replaced a 261 KB version from 2022.

Verified working against **M8 Headless firmware 6.5.2**: display, audio and
controls all confirmed, and m8c logs
`** Hardware info ** Device type: Headless, Firmware ver 6.5.2`.

## Restoring

```bash
scp prebuilt/m8c-v1.7.10-aarch64-arkos ark@<device>:/roms/ports/M8/_m8c/m8c
scp prebuilt/gamecontrollerdb.txt      ark@<device>:/roms/ports/M8/_m8c/
ssh ark@<device> chmod 755 /roms/ports/M8/_m8c/m8c
```

The device also keeps the original Nov 2022 binary it replaced, at
`/roms/ports/M8/_m8c/m8c.bak-2022` (55616 bytes, roughly v1.4 era).

## Rebuilding from source

`ports/M8/setup/build_m8c.sh` clones upstream, checks out `M8C_REF` (default
`v1.7.10`) and builds. Takes about ten seconds on the device.

## Known limitation

This build detects the M8 by USB id `0x16C0:0x048A` only. Firmware 6.5.0's
multichannel USB audio mode enumerates as a **second product id**, which m8c
only learned about in v2.2.2. See [../docs/plan.md](../docs/plan.md).

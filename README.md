# NextUI Sega Dreamcast Pak (`DC.pak`)

A high-performance Sega Dreamcast emulator pak for [NextUI](https://github.com/LoveRetro/NextUI) powered by [Flycastrophe](https://github.com/Helaas/Flycastrophe) (an optimized fork of Flycast) and MinArch hardware-accelerated rendering (`SET_HW_RENDER`).

Supports `tg5040` (TrimUI Smart Pro, TrimUI Brick), `tg5050` (TrimUI Smart Pro S, TrimUI Brick Pro), and `h700` (Anbernic RG35XX series) devices running NextUI.

---

## Features

- **Flycastrophe Speedups**: Aggressive wait-loop skipping, fast FIPR vector math, threaded audio mixer, and parse thread optimizations delivering up to **+59% faster 3D rendering** over upstream Flycast on ARM Cortex-A53 handhelds.
- **Hardware Rendering**: Direct OpenGLES rendering via MinArch's `SET_HW_RENDER` framebuffer pipeline.
- **Device-Aware Defaults**: Automatic widescreen presentation on 16:9 displays (TrimUI Smart Pro) and native 4:3 presentation on handhelds like TrimUI Brick and Anbernic RG35XX.
- **RetroAchievements Ready**: Full memory mapping support (`RETRO_MEMORY_SYSTEM_RAM`) for Dreamcast achievements.

---

## Requirements

- **NextUI** with MinArch hardware-rendering support (`SET_HW_RENDER` and Dreamcast GD-ROM RetroAchievements support).
- Compatible handheld:
  - **tg5040**: TrimUI Smart Pro, TrimUI Brick (Allwinner A133p / PowerVR GE8300)
  - **tg5050**: TrimUI Smart Pro S, TrimUI Brick Pro
  - **h700**: Anbernic RG35XX Plus, RG35XX H, RG35XX SP, RG40XX (Allwinner H700 / Mali-G31 MP2)

---

## Installation

### Via NextUI Pak Store
Install `DC` directly from the NextUI Pak Store interface on your device.

### Manual Installation
1. Download `DC.pak.zip` from the latest [GitHub Releases](https://github.com/Pobega/nextui-flycastrophe-pak/releases).
2. Extract the archive directly to your SD card under your platform's emulator directory:
   - For TrimUI Smart Pro / Brick: `/mnt/SDCARD/Emus/tg5040/DC.pak/`
   - For Anbernic RG35XX series: `/mnt/SDCARD/Emus/h700/DC.pak/`
3. Alternatively, extract the unified multi-platform layout directly to `/mnt/SDCARD/Emus/$PLATFORM/DC.pak/`.

---

## BIOS Setup

Dreamcast BIOS files are **optional**. Flycastrophe includes a built-in HLE BIOS that can boot most commercial titles directly.

For maximal compatibility, place original Dreamcast BIOS files into:
```
/mnt/SDCARD/Bios/DC/
```
Supported files:
- `dc_boot.bin` (Dreamcast Boot ROM)
- `dc_flash.bin` (Dreamcast Flash ROM / NVRAM)
- `boot.bin` / `dc_nvmem.bin`
- Arcade BIOS files (`naomi.zip`, `awbios.zip`, `hod2bios.zip`, `f355dlx.zip`)

`launch.sh` automatically synchronizes BIOS files from `Bios/DC/` into the emulator's internal `Bios/DC/dc/` directory on launch.

---

## ROM Paths and Formats

Place Dreamcast game images in:
```
/mnt/SDCARD/Roms/Sega Dreamcast (DC)/
```

Supported formats:
- **CHD** (`.chd`, recommended for GD-ROM compression and performance)
- **CDI** (`.cdi`)
- **GDI** (`.gdi`)
- **M3U** (`.m3u` multi-disc playlists)

---

## Default Controls & Options

### Default Controls (Dreamcast Controller Port 0)
| NextUI Handheld | Dreamcast Button |
| :--- | :--- |
| **D-Pad** | D-Pad |
| **A** | B |
| **B** | A |
| **X** | Y |
| **Y** | X |
| **L1** | L Trigger |
| **R1** | R Trigger |
| **Start** | Start |
| **Menu** | MinArch Quick Menu |

### Core Options & Tuning
Default options are tuned for maximum speed while preserving rendering stability:
- `reicast_device_port1_slot2 = None`: Disables the Purupuru Vibration Pack by default (re-enable in **Options -> Emulator -> Expansions** if desired).
- `reicast_threaded_rendering = enabled`: Runs emulation and renderer across multiple CPU cores.
- `reicast_vblank_pacing = enabled`: Paces each `retro_run` to one Dreamcast vblank so 30 FPS games stay at 100% real-time speed alongside threaded rendering.
- `reicast_delay_frame_swapping = disabled`: Presents rendered frames immediately without waiting for framebuffer swap match.
- `reicast_gdrom_fast_loading = enabled`: Speeds up GD-ROM disc reads.
- `reicast_alpha_sorting = per-strip (fast, least accurate)`: Fast alpha sorting for Cortex-A53 GPUs.
- `reicast_auto_skip_frame = disabled`: Avoids false-positive frame skips while keeping full-speed pacing.
- `reicast_widescreen_hack`: Automatically enabled on 16:9 displays (`default-smartpro.cfg`) and disabled on 4:3 screens (`default.cfg`, `default-brick.cfg`).
- `reicast_fcr_* = enabled`: Enables Flycastrophe's off-thread polygon parser, fast `fipr` math, SH4 wait-loop skip, and threaded AICA audio.
- `reicast_dpad_to_analog`: Maps D-Pad inputs to the Dreamcast Left Analog Stick (`disabled`, `analog` for Left Stick only, or `both` for Left Stick + D-Pad), with a quadratic ease-in ramp (`reicast_dpad_to_analog_ramp`, defaults to `medium` 220 ms) and max deflection (`reicast_dpad_to_analog_sensitivity`). Enabled (`both`) by default on stickless handhelds (`default.cfg`, `default-brick.cfg`, `default-brickpro.cfg`) and `disabled` on Smart Pro (`default-smartpro.cfg`, `default-smartpros.cfg`).

---

## Building from Source

### Prerequisites
- `make`
- `podman` or `docker`
- `jq`, `zip`

The build system leverages official LoveRetro cross-compiler toolchains:
- `ghcr.io/loveretro/tg5040-toolchain:latest` (GCC 8.3.0 + GLIBC)
- `ghcr.io/loveretro/h700-toolchain:latest` (GCC 8.3.0 + GLIBC)

### Build Targets
```bash
# Build both tg5040 and h700 cores and create dist/DC.pak.zip
make release

# Build tg5040 core only
make build-tg5040

# Build h700 core only
make build-h700

# Package release zip and standalone platform folders
make package

# Clean build artifacts
make clean
```

---

## License

This project packages [Flycastrophe](https://github.com/Helaas/Flycastrophe) and Flycast, which are licensed under the GNU General Public License v2 (GPL-2.0). See [LICENSE](LICENSE) for full details.

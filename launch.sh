#!/bin/sh

EMU_EXE=flycastrophe
PAK_DIR="$(cd "$(dirname "$0")" && pwd)"
EMU_TAG=$(basename "$PAK_DIR" .pak)
ROM="$1"

mkdir -p "$BIOS_PATH/$EMU_TAG/dc"
mkdir -p "$SAVES_PATH/$EMU_TAG"
mkdir -p "$CHEATS_PATH/$EMU_TAG"
HOME="$USERDATA_PATH"
cd "$HOME" || exit 1

# Flycast libretro reads BIOS files from <system_dir>/dc; sync files placed directly in $BIOS_PATH/$EMU_TAG
for bios_file in dc_boot.bin dc_flash.bin dc_nvmem.bin boot.bin naomi.zip hod2bios.zip f355dlx.zip f355bios.zip awbios.zip; do
	if [ -f "$BIOS_PATH/$EMU_TAG/$bios_file" ] && [ ! -f "$BIOS_PATH/$EMU_TAG/dc/$bios_file" ]; then
		cp "$BIOS_PATH/$EMU_TAG/$bios_file" "$BIOS_PATH/$EMU_TAG/dc/$bios_file" 2>/dev/null
	fi
done

echo 1 >/sys/devices/system/cpu/cpu1/online 2>/dev/null
echo 1 >/sys/devices/system/cpu/cpu2/online 2>/dev/null
echo 1 >/sys/devices/system/cpu/cpu3/online 2>/dev/null

if [ -n "$PLATFORM" ] && [ -f "$PAK_DIR/cores/$PLATFORM/${EMU_EXE}_libretro.so" ]; then
	CORE_SO="$PAK_DIR/cores/$PLATFORM/${EMU_EXE}_libretro.so"
else
	CORE_SO="$PAK_DIR/${EMU_EXE}_libretro.so"
fi

if [ -n "$PLATFORM" ] && [ -f "$PAK_DIR/bin/$PLATFORM/minarch.elf" ]; then
	MINARCH="$PAK_DIR/bin/$PLATFORM/minarch.elf"
elif [ -f "$PAK_DIR/minarch.elf" ]; then
	MINARCH="$PAK_DIR/minarch.elf"
else
	MINARCH="minarch.elf"
fi

"$MINARCH" "$CORE_SO" "$ROM" > "$LOGS_PATH/$EMU_TAG.txt" 2>&1

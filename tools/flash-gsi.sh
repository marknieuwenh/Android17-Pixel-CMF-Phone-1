#!/usr/bin/env bash
# Guided GSI flash for the CMF Phone 1. Every step that writes to the phone asks first.
#
#   tools/flash-gsi.sh --system system.img --vbmeta vbmeta.img [--init-boot magisk_patched.img]
#
# --system     Android 17 GSI system image (arm64, preferably the +GMS variant).
# --vbmeta     vbmeta.img from your phone's current Nothing OS firmware. It is
#              flashed with verification disabled so the GSI is allowed to boot.
# --init-boot  Optional Magisk-patched init_boot.img (same firmware) for root.
#
# Start with the phone in the bootloader (fastboot mode) and the bootloader unlocked.
# This wipes user data.
set -euo pipefail

SYSTEM="" VBMETA="" INIT_BOOT=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --system) SYSTEM=$2; shift 2 ;;
        --vbmeta) VBMETA=$2; shift 2 ;;
        --init-boot) INIT_BOOT=$2; shift 2 ;;
        -h|--help) sed -n '2,14p' "$0"; exit 0 ;;
        *) echo "!! Unknown argument $1" >&2; exit 1 ;;
    esac
done
[[ -f "$SYSTEM" && -f "$VBMETA" ]] || { sed -n '2,14p' "$0"; exit 1; }
[[ -z "$INIT_BOOT" || -f "$INIT_BOOT" ]] || { echo "!! $INIT_BOOT not found" >&2; exit 1; }
command -v fastboot >/dev/null || { echo "!! fastboot not found in PATH" >&2; exit 1; }

confirm() {
    local reply
    read -r -p "$1 [y/N] " reply
    [[ "$reply" == [yY] ]]
}

getvar() { { timeout 5 fastboot getvar "$1" 2>&1 || true; } | sed -n "s/^$1: //p" | head -n1; }

echo ">> Waiting for the phone in fastboot mode"
fastboot devices | grep -q . || { echo "!! No fastboot device. Boot to the bootloader (Power + Volume down)." >&2; exit 1; }

product=$(getvar product)
unlocked=$(getvar unlocked)
slot=$(getvar current-slot)
slot=${slot#_}   # some bootloaders report "_a", most report "a"
product_part="product${slot:+_$slot}"
echo "   product=$product unlocked=$unlocked slot=$slot"
if [[ "${product,,}" != *tetris* ]]; then
    echo "!! fastboot reports product '$product', not Tetris (CMF Phone 1)."
    confirm "   Only continue if you are sure this is a CMF Phone 1. Continue?" || exit 1
fi
[[ "$unlocked" == "yes" ]] || { echo "!! Bootloader is locked. See docs/INSTALL.md step 6." >&2; exit 1; }

echo
echo "About to:"
echo "  1. flash vbmeta with verification disabled"
echo "  2. reboot to fastbootd and replace the system partition with the GSI"
[[ -n "$INIT_BOOT" ]] && echo "  3. flash the Magisk-patched init_boot"
echo "  and then wipe user data (asked separately)"
confirm "This erases everything on the phone. Proceed?" || exit 1

fastboot --disable-verity --disable-verification flash vbmeta "$VBMETA"

echo ">> Rebooting to fastbootd (userspace fastboot, needed for dynamic partitions)"
fastboot reboot fastboot
for _ in $(seq 60); do
    [[ "$(getvar is-userspace)" == "yes" ]] && break
    sleep 1
done
[[ "$(getvar is-userspace)" == "yes" ]] || { echo "!! Phone did not come back in fastbootd. Run the script again from the bootloader." >&2; exit 1; }

fastboot erase system
if ! fastboot flash system "$SYSTEM"; then
    # The GMS GSI can be larger than the stock system partition. The GSI does
    # not use the stock product partition, so removing it frees the space.
    echo "!! Not enough room for the GSI in the dynamic partition group."
    if confirm "   Delete the unused product partition ($product_part) and retry?"; then
        fastboot delete-logical-partition "$product_part"
        fastboot flash system "$SYSTEM"
    else
        exit 1
    fi
fi

if [[ -n "$INIT_BOOT" ]]; then
    fastboot flash init_boot "$INIT_BOOT"
fi

if confirm "Wipe user data now? (required on first GSI install)"; then
    fastboot -w
fi

echo ">> Rebooting. The first boot can take several minutes."
fastboot reboot
echo "   Next: docs/INSTALL.md step 8 (Magisk + module)"

#!/usr/bin/env bash
# Run this while the phone is still on stock Nothing OS, before flashing the GSI.
#
# The GSI skips the stock /product and /system_ext partitions, and that is where
# Nothing keeps most of the CMF Phone 1 hardware tuning (display cutout, rounded
# corners, brightness curve, fingerprint sensor position, refresh rate). This
# script saves that tuning so build-module.sh can carry it over to the GSI.
#
# Needs: adb, USB debugging enabled. Root is not required.
# Output: stock/ in the repo root (git-ignored, it contains Nothing's files).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${1:-$ROOT/stock}"

command -v adb >/dev/null || { echo "!! adb not found in PATH" >&2; exit 1; }
adb get-state >/dev/null 2>&1 || { echo "!! No device found. Enable USB debugging and accept the prompt." >&2; exit 1; }

device=$(adb shell getprop ro.product.vendor.device | tr -d '\r')
model=$(adb shell getprop ro.product.vendor.model | tr -d '\r')
platform=$(adb shell getprop ro.board.platform | tr -d '\r')
echo ">> Device: $device / $model / $platform"
if [[ "${device,,}" != "tetris" && "$platform" != "mt6878" ]]; then
    echo "!! This does not look like a CMF Phone 1 (expected device Tetris, platform mt6878)." >&2
    [[ "${FORCE:-0}" == 1 ]] || { echo "   Set FORCE=1 to continue anyway." >&2; exit 1; }
fi

rm -rf "$OUT"
mkdir -p "$OUT/overlays" "$OUT/dumps"

echo ">> Saving properties and system state"
adb shell getprop > "$OUT/dumps/getprop.txt"
adb shell pm list features | tr -d '\r' | sed 's/^feature://' | sort > "$OUT/dumps/features.txt"
adb shell cmd overlay list | tr -d '\r' > "$OUT/dumps/overlay-list.txt"
for svc in display fingerprint SurfaceFlinger power battery; do
    adb shell dumpsys "$svc" > "$OUT/dumps/dumpsys-$svc.txt" 2>/dev/null || true
done
adb shell wm size > "$OUT/dumps/wm.txt"
adb shell wm density >> "$OUT/dumps/wm.txt"

# Only overlays that are enabled on stock are carried over, in the order
# `cmd overlay list` prints them (lowest priority first). Overlays on vendor and
# odm are skipped because the GSI keeps loading those partitions itself.
echo ">> Pulling enabled overlays from product, system_ext and system"
: > "$OUT/overlays/order.txt"
grep -E '^\s*\[x\]' "$OUT/dumps/overlay-list.txt" | awk '{print $2}' | while read -r pkg; do
    path=$(adb shell pm path "$pkg" </dev/null | tr -d '\r' | sed -n 's/^package://p' | head -n1)
    case "$path" in
        /product/*|/system_ext/*|/system/*) ;;
        *) continue ;;
    esac
    if adb pull "$path" "$OUT/overlays/$pkg.apk" </dev/null >/dev/null 2>&1; then
        echo "$pkg $path" >> "$OUT/overlays/order.txt"
        echo "   $pkg"
    else
        echo "   (could not read $path, skipped)"
    fi
done

echo ">> Done: $(wc -l < "$OUT/overlays/order.txt") overlays saved to $OUT"
echo "   Next: tools/build-module.sh (it reads $OUT automatically)"

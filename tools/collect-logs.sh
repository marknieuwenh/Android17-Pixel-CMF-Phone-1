#!/usr/bin/env bash
# Collects diagnostics from the phone running the GSI and compares it with the
# stock Nothing OS dump, so broken hardware can be narrowed down quickly.
#
#   tools/collect-logs.sh [output dir]      (default: logs/<timestamp>)
#
# Needs adb and USB debugging. Root (Magisk) adds kernel logs.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${1:-$ROOT/logs/$(date +%Y%m%d-%H%M%S)}"
STOCK="$ROOT/stock"
mkdir -p "$OUT"

adb get-state >/dev/null 2>&1 || { echo "!! No device found over adb" >&2; exit 1; }
ashell() { adb shell "$@" </dev/null | tr -d '\r'; }

echo ">> Collecting into $OUT"
ashell getprop > "$OUT/getprop.txt"
ashell pm list features | sed 's/^feature://' | sort > "$OUT/features.txt"
ashell cmd overlay list > "$OUT/overlay-list.txt"
for svc in display fingerprint SurfaceFlinger power battery media.camera telephony.registry; do
    ashell dumpsys "$svc" > "$OUT/dumpsys-$svc.txt" 2>/dev/null || true
done
ashell logcat -b all -d > "$OUT/logcat.txt" || true
if ashell su -c true >/dev/null 2>&1; then
    ashell su -c dmesg > "$OUT/dmesg.txt" || true
    ashell su -c "cat /data/adb/modules/cmf_tetris_gsi/service.log" > "$OUT/module-service.log" 2>/dev/null || true
else
    echo "   (no root: skipping dmesg)"
fi

{
    echo "# GSI health check"
    echo
    echo "- GSI build: $(grep -m1 '\[ro.system.build.fingerprint\]' "$OUT/getprop.txt" | cut -d'[' -f3 | tr -d ']')"
    echo "- Vendor: $(grep -m1 '\[ro.vendor.build.fingerprint\]' "$OUT/getprop.txt" | cut -d'[' -f3 | tr -d ']')"
    echo
    echo "## Module overlays"
    grep -i cmftetris "$OUT/overlay-list.txt" || echo "None found: the module is not installed or its overlays did not load."
    echo
    echo "## Crashing processes"
    grep -E 'FATAL EXCEPTION|Fatal signal|ANR in' -A2 "$OUT/logcat.txt" | grep -E 'Process:|ANR in|>>>' | sort | uniq -c | sort -rn | head -20 || true
    echo
    echo "## HAL services that failed to start"
    grep -iE 'Could not find .*(HAL|service)|failed to get service|service .* not found' "$OUT/logcat.txt" | sed 's/^.*: //' | sort | uniq -c | sort -rn | head -20 || true
    if [[ -f "$STOCK/dumps/features.txt" ]]; then
        echo
        echo "## Features on stock but missing on the GSI"
        comm -23 "$STOCK/dumps/features.txt" "$OUT/features.txt" || true
    fi
} > "$OUT/SUMMARY.md"

cat "$OUT/SUMMARY.md"
echo
echo ">> Full logs in $OUT. They can contain personal data (accounts, Wi-Fi names), check before sharing."

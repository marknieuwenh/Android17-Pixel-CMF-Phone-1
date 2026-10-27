#!/usr/bin/env bash
# Gets Pixel Launcher (NexusLauncherRelease.apk) for bundling into the module.
# Pixel Launcher is Google's proprietary app, so it is never stored in this repo.
#
#   tools/get-pixel-launcher.sh --factory-image <pixel-factory-image.zip>
#   tools/get-pixel-launcher.sh --from-device          (a Pixel connected over adb)
#
# Use an image or a Pixel that runs the same Android 17 release as your GSI:
# Pixel Launcher's recents code is tied to the framework version.
# Needs for --factory-image: unzip, and fsck.erofs (erofs-utils) or debugfs
# (e2fsprogs) depending on the image; simg2img (android-sdk-libsparse-utils)
# for sparse images.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/pixel-launcher"
work=""
APK_PATH=priv-app/NexusLauncherRelease/NexusLauncherRelease.apk

need() { command -v "$1" >/dev/null || { echo "!! $1 is required ($2)" >&2; exit 1; }; }

from_device() {
    need adb "Android platform-tools"
    local path
    path=$(adb shell pm path com.google.android.apps.nexuslauncher | tr -d '\r' | sed -n 's/^package://p' | head -n1)
    [[ -n "$path" ]] || { echo "!! Pixel Launcher not found on the connected device" >&2; exit 1; }
    mkdir -p "$OUT"
    adb pull "$path" "$OUT/NexusLauncherRelease.apk"
}

from_factory_image() {
    local image=$1
    need unzip "unzip"
    work=$(mktemp -d)
    trap 'rm -rf "$work"' EXIT

    echo ">> Unpacking $image"
    unzip -q -j "$image" '*/image-*.zip' -d "$work"
    unzip -q "$work"/image-*.zip product.img -d "$work"
    local img="$work/product.img"

    # Android sparse image magic: 3a ff 26 ed
    if [[ "$(head -c4 "$img" | od -An -tx1 | tr -d ' ')" == "3aff26ed" ]]; then
        need simg2img "android-sdk-libsparse-utils"
        simg2img "$img" "$img.raw" && mv "$img.raw" "$img"
    fi

    mkdir -p "$OUT"
    # EROFS superblock magic e2 e1 f5 e0 at offset 1024, ext4 magic 53 ef at 1080
    if [[ "$(od -An -tx1 -j1024 -N4 "$img" | tr -d ' ')" == "e2e1f5e0" ]]; then
        need fsck.erofs "erofs-utils"
        fsck.erofs --extract="$work/product" "$img" >/dev/null
        cp "$work/product/$APK_PATH" "$OUT/"
    elif [[ "$(od -An -tx1 -j1080 -N2 "$img" | tr -d ' ')" == "53ef" ]]; then
        need debugfs "e2fsprogs"
        debugfs -R "dump /$APK_PATH $OUT/NexusLauncherRelease.apk" "$img" 2>/dev/null
    else
        echo "!! product.img is neither EROFS nor ext4" >&2
        exit 1
    fi
}

case "${1:-}" in
    --from-device) from_device ;;
    --factory-image) [[ -f "${2:-}" ]] || { echo "!! Give the factory image zip" >&2; exit 1; }
                     from_factory_image "$2" ;;
    *) sed -n '2,13p' "$0"; exit 1 ;;
esac

[[ -s "$OUT/NexusLauncherRelease.apk" ]] || { echo "!! Extraction failed" >&2; exit 1; }
echo ">> Saved $OUT/NexusLauncherRelease.apk"
echo "   Next: tools/build-module.sh --pixel-launcher $OUT/NexusLauncherRelease.apk"

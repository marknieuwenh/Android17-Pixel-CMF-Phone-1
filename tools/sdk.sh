#!/usr/bin/env bash
# Fetches the Android build-tools (aapt2, apksigner) and the API 37 android.jar,
# verifies them against pinned checksums and caches them in .cache/sdk.
# Source this file; it exports AAPT2, APKSIGNER_JAR and ANDROID_JAR.

SDK_DIR="${SDK_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/.cache/sdk}"
BUILD_TOOLS_ZIP=build-tools_r37_linux.zip
BUILD_TOOLS_SHA256=01af179347cbcd9c208b7f8171f7b21f6dd1d2f85bcd15e88caa51d5d7b86060
PLATFORM_ZIP=platform-37.0_r02.zip
PLATFORM_SHA256=840b23e827f96e64aea4c89a1194aac3dc5f6bad37edb231c5c795d890330e8d
REPO_URL=https://dl.google.com/android/repository

_sdk_fetch() {
    local name=$1 sha=$2
    if [[ ! -f "$SDK_DIR/$name" ]]; then
        echo ">> Downloading $name" >&2
        curl -fSL --retry 4 -o "$SDK_DIR/$name.part" "$REPO_URL/$name" || return 1
        mv "$SDK_DIR/$name.part" "$SDK_DIR/$name"
    fi
    echo "$sha  $SDK_DIR/$name" | sha256sum -c --quiet - || {
        echo "!! Checksum mismatch for $name, delete it and retry" >&2
        return 1
    }
}

sdk_setup() {
    mkdir -p "$SDK_DIR"
    if [[ ! -x "$SDK_DIR/android-37.0/aapt2" ]]; then
        _sdk_fetch "$BUILD_TOOLS_ZIP" "$BUILD_TOOLS_SHA256" || return 1
        unzip -qo "$SDK_DIR/$BUILD_TOOLS_ZIP" -d "$SDK_DIR"
    fi
    if [[ ! -f "$SDK_DIR/platform/android-37.0/android.jar" ]]; then
        _sdk_fetch "$PLATFORM_ZIP" "$PLATFORM_SHA256" || return 1
        unzip -qo "$SDK_DIR/$PLATFORM_ZIP" android-37.0/android.jar -d "$SDK_DIR/platform"
    fi
    export AAPT2="$SDK_DIR/android-37.0/aapt2"
    export APKSIGNER_JAR="$SDK_DIR/android-37.0/lib/apksigner.jar"
    export ANDROID_JAR="$SDK_DIR/platform/android-37.0/android.jar"
}

# Installing

You need a computer running Linux or macOS (on Windows, use WSL with USB passthrough
via `usbipd`), [Android platform-tools](https://developer.android.com/tools/releases/platform-tools)
(`adb`, `fastboot`), `python3`, `java`, `curl`, `unzip` and `zip`.

Do the steps in order. Step 1 has to happen while the phone still runs Nothing OS.

## 1. Save the stock tuning (on Nothing OS)

1. Settings → About phone → tap *Build number* 7 times to enable Developer options.
2. Settings → System → Developer options → enable **USB debugging** and **OEM unlocking**.
3. Connect the phone, accept the USB debugging prompt, then run:

   ```bash
   tools/extract-stock.sh
   ```

   This writes `stock/` (git-ignored). Keep a copy somewhere safe: it is the only
   source of the phone's tuning once Nothing OS is gone.

4. Back up your data. The next steps erase the phone.

## 2. Get the stock firmware images

You need two images from the **exact Nothing OS build that's on your phone** (Settings →
About phone):

- `vbmeta.img`: flashed with verification disabled so the GSI can boot
- `init_boot.img`: patched with Magisk for root

Get the full OTA zip for that build and pull the images out of its `payload.bin`
with [payload-dumper-go](https://github.com/ssut/payload-dumper-go):

```bash
payload-dumper-go -p vbmeta,init_boot payload.bin
```

Keep all the stock images if you can. You'll need them to go back to Nothing OS.

## 3. Root image

Install the [Magisk](https://github.com/topjohnwu/Magisk/releases) app (on the
stock phone is fine). In Magisk: **Install → Select and Patch a File →**
`init_boot.img`. Copy the resulting `magisk_patched-*.img` to your computer.

## 4. Download the GSI

From Google's [Android 17 GSI release notes](https://developer.android.com/about/versions/17/gsi-release-notes),
download the **ARM64 + GMS** image. The GMS variant gives Pixel Launcher its Google
search bar, At a Glance and feed. Check the SHA-256 against the page, then unzip it
to get `system.img`. Note the **build ID** (for example `CP2A.260605.012`); you need it
in the next step.

## 5. Build the module

1. Pixel Launcher must come from the **same Android 17 release** as the GSI. Its
   recents code is tied to the framework, and a mismatched one crashes on swipe-up.
   Download the factory image for any recent Pixel with the same build ID (or the
   closest one) from [developers.google.com/android/images](https://developers.google.com/android/images), then:

   ```bash
   tools/get-pixel-launcher.sh --factory-image ~/Downloads/<pixel>-<build>-factory-*.zip
   ```

   If you have a Pixel on that release, `tools/get-pixel-launcher.sh --from-device` also works.

2. Build:

   ```bash
   tools/build-module.sh --pixel-launcher pixel-launcher/NexusLauncherRelease.apk
   ```

   Check `out/build/stock-res/REPORT.md`: it lists every stock value that was
   carried over, which overlay it came from, and anything that was skipped.

## 6. Unlock the bootloader

This wipes the phone.

```bash
adb reboot bootloader
fastboot flashing unlock
```

Confirm on the phone with the volume keys and power button. It wipes and reboots.
Skip the setup and go back to the bootloader: `adb reboot bootloader` (re-enable USB
debugging), or hold **Power + Volume down** while it powers on.

## 7. Flash

With the phone in the bootloader:

```bash
tools/flash-gsi.sh --system system.img --vbmeta vbmeta.img --init-boot magisk_patched-*.img
```

The script checks that it's talking to an unlocked Tetris and asks before each
destructive step. If the GMS image doesn't fit, it offers to remove the unused stock
`product` partition (the GSI doesn't mount it) and retry. The first boot takes a few minutes.

## 8. Install the module

1. Set up Android, enable USB debugging again.
2. Install the Magisk app and open it. If it asks for additional setup, let it reboot.
3. Copy `out/cmf-phone-1-gsi-tuning-*.zip` to the phone. In Magisk: **Modules →
   Install from storage** → pick the zip → **Reboot**.

After the reboot, Pixel Launcher is the home app and handles recents and gestures.
If Android asks which home app to use, pick Pixel Launcher.

## 9. Check it

```bash
tools/collect-logs.sh
```

It prints a short health report: whether the module overlays loaded, crashing
processes, HAL services that failed, and hardware features that were present on
stock but are missing now. Then check by hand:

- [ ] Status bar clears the punch-hole camera; screen corners are rounded properly
- [ ] Brightness slider covers the full range; auto-brightness reacts to light
- [ ] Settings → Display → Smooth display / refresh rate reaches 120 Hz
- [ ] Fingerprint enrolment and unlock; the icon sits over the sensor
- [ ] Calls on 4G (VoLTE), mobile data, SMS, Wi-Fi, Bluetooth, GPS, NFC
- [ ] Rear and front cameras, flash, video recording
- [ ] Speaker, earpiece, microphone in calls, wired/Bluetooth audio
- [ ] Charging and battery percentage
- [ ] Swipe-up recents, back gesture, app drawer, widgets in Pixel Launcher

Open an issue with the `logs/` summary for anything that fails.

## Going back to Nothing OS

In fastbootd (`fastboot reboot fastboot`) flash the stock images you kept:
`system`, `system_ext`, `product`, `vendor`, `odm`, `init_boot` and `vbmeta` (this
time without the `--disable-*` flags), then `fastboot -w` and reboot. If you
deleted `product` in step 7, recreate it first with
`fastboot create-logical-partition product_a <size-in-bytes>` (use the size of your stock `product.img`).
Lock the bootloader (`fastboot flashing lock`) only once stock Nothing OS boots properly.

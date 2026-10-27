# Android 17 + Pixel Launcher on the CMF Phone 1

Run Google's Android 17 GSI (Generic System Image) on the CMF Phone 1 (codename
**Tetris**, model A015, MediaTek Dimensity 7300), with the phone's own hardware
tuning carried over from Nothing OS and Pixel Launcher as the home and recents app.

> **Status: untested on hardware.** The tooling is built and tested on a
> computer, but nobody has booted this on a CMF Phone 1 yet. Expect to report
> back and iterate. Read [docs/KNOWN-ISSUES.md](docs/KNOWN-ISSUES.md) before you start.

## Why not just flash a GSI?

A plain GSI only knows generic Android. On stock, Nothing keeps most of the
CMF Phone 1 hardware description in the `/product` and `/system_ext`
partitions, and a GSI skips both. That's why a bare GSI usually gets the punch-hole
cutout, rounded corners, brightness range, auto-brightness curve, 120 Hz and the
under-display fingerprint position wrong.

This project:

1. **Copies the tuning from your own phone** while it still runs Nothing OS
   (`tools/extract-stock.sh`). That covers every enabled stock overlay plus
   hardware features, display and fingerprint state.
2. **Keeps only hardware values** (allow-list in
   [config/carry-over.conf](config/carry-over.conf)) and compiles them into
   overlays for the GSI (`tools/stock2overlay.py`). Nothing's apps, services and
   theming are left out because they don't exist on the GSI.
3. **Installs Pixel Launcher** as a privileged app with its permissions generated
   from the APK, hidden-API access, the recents-provider overlay and the home role.
   It also hides the GSI's own launcher.
4. Packs everything into **one Magisk module**, so the GSI itself stays
   untouched and you can remove the module to go back.

## Quick start

Full walkthrough: **[docs/INSTALL.md](docs/INSTALL.md)**.

```bash
tools/extract-stock.sh                                   # on stock Nothing OS, before anything else
tools/get-pixel-launcher.sh --factory-image <pixel-android17-factory.zip>
tools/build-module.sh --pixel-launcher pixel-launcher/NexusLauncherRelease.apk
tools/flash-gsi.sh --system system.img --vbmeta vbmeta.img --init-boot magisk_patched.img
# boot, install Magisk, install out/cmf-phone-1-gsi-tuning-*.zip as a module, reboot
tools/collect-logs.sh                                    # health check + logs for bug reports
```

## Layout

| Path | What it is |
| --- | --- |
| `tools/extract-stock.sh` | Saves stock overlays, features and display/fingerprint state over adb |
| `tools/stock2overlay.py` | Turns those overlays into GSI overlay sources (allow-listed values only) |
| `tools/build-module.sh` | Compiles and signs the overlays, bundles Pixel Launcher, builds the module zip |
| `tools/get-pixel-launcher.sh` | Extracts Pixel Launcher from a Pixel factory image or a Pixel over adb |
| `tools/flash-gsi.sh` | Guided fastboot flash with confirmations |
| `tools/collect-logs.sh` | Diagnostics after flashing, compared with the stock dump |
| `config/carry-over.conf` | Which stock values are carried over |
| `overlays/` | Overlays shipped with the module (baseline values, Pixel Launcher recents) |
| `module/` | Magisk module template |
| `docs/` | Install guide, tuning details, known issues |

## Proprietary files

Pixel Launcher and Nothing's overlays are proprietary. They're never committed:
`stock/`, `pixel-launcher/` and all APK and image files are git-ignored. You build
the module locally from your own phone and a Pixel image you download yourself.
CI only builds the tuning-only module.

## Disclaimer

Unlocking the bootloader wipes the phone, can affect warranty, and breaks apps that
need Play Integrity (banking, Google Wallet). Flashing the wrong images can leave the
phone unbootable. You do this at your own risk.

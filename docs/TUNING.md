# How the device tuning works

## What a GSI keeps and what it loses

| Partition | On the GSI | Holds |
| --- | --- | --- |
| `vendor`, `odm`, `vendor_dlkm` | **Kept** (stock Nothing) | HALs: display, camera, fingerprint, audio, sensors, modem, kernel modules |
| `boot`, `init_boot`, `vendor_boot` | **Kept** (stock kernel) | Kernel and ramdisks |
| `system` | **Replaced** by the GSI | Android framework |
| `product`, `system_ext` | **Not mounted** (the GSI uses its own) | Nothing's apps and most of the device's framework/SystemUI overlays |

So drivers and HALs keep working as long as the GSI's framework can talk to them,
but the *descriptions* of the hardware that live in Nothing's overlays are lost.
This project puts them back.

## Overlay layers

All overlays are static runtime resource overlays (RROs) in `/product/overlay`,
installed by the Magisk module. A higher priority wins:

| Priority | Overlay | Source |
| --- | --- | --- |
| 800 | `TetrisFrameworkBase` | `overlays/TetrisFrameworkBase`: spec-sheet values (120 Hz, AOD, light sensor). Fallback when there is no stock dump. |
| 900 | `TetrisStockFramework`, `TetrisStockSystemUI` | Generated from **your** phone's stock overlays by `tools/stock2overlay.py` |
| 990 | `PixelLauncherRecents` | `overlays/PixelLauncherRecents`: makes Pixel Launcher the recents provider |

## What is carried over

[config/carry-over.conf](../config/carry-over.conf) is the allow-list. Currently:

- **Display:** cutout path and its rectangle approximation, rounded corner radii,
  status bar heights around the punch hole
- **Brightness:** panel min/max/default, dim and doze levels, nits mapping,
  auto-brightness levels and curves, ambient light thresholds, even dimmer
- **Refresh rate:** default peak/min rates and refresh-rate zones
- **AOD/doze:** availability and pickup/tap sensors (not Nothing's doze service)
- **Fingerprint:** UDFPS/SFPS sensor position and size
- **Haptics:** vibration patterns and haptic feedback settings
- **Battery:** low/critical warning levels
- **SystemUI:** rounded corners, cutout padding, fingerprint icon placement

Only `bool`, `integer`, `dimen`, `array` and, for the cutout, `string` values are
carried over. References to other resources are skipped, because they point into
Nothing's own packages. Every carried and skipped value is listed in
`out/build/stock-res/REPORT.md`, and that report is also included in the module.

### Adding a value

If `tools/collect-logs.sh` or the checklist shows something that's still wrong, look up the
stock value:

```bash
.cache/sdk/android-37.0/aapt2 dump resources stock/overlays/<overlay>.apk | less
```

Add a line for it in `config/carry-over.conf`, rebuild, reinstall the module and
reboot. Keep the rules narrow: anything that names a Nothing app or service will break
the GSI.

### Hardware features

`stock/dumps/features.txt` is the stock `pm list features`. Its `android.hardware.*`
entries are declared again by the module (`cmf-tetris-hardware.xml`), except
`telephony.ims`, `vulkan.*` and `opengles.*`. Vulkan and OpenGL ES come from the
vendor partition anyway, and IMS needs Nothing's MediaTek IMS stack, which the GSI
doesn't have. Declaring a feature only tells apps it exists. It can't make
missing software work.

## Pixel Launcher integration

- Installed as `/product/priv-app/NexusLauncherRelease` (privileged).
- `privapp-permissions-nexuslauncher.xml` is generated from the APK's own
  permission list. Android refuses to boot if a privileged app requests a
  privileged permission that isn't listed, so a fixed list would break with
  every launcher update.
- `nexuslauncher-hiddenapi.xml` gives it access to the hidden framework APIs
  that recents and gestures need.
- `PixelLauncherRecents` sets `config_recentsComponentName` so swipe-up goes
  through Pixel Launcher (quickstep).
- `Launcher3QuickStep`/`Launcher3`/`TrebuchetQuickStep` from the GSI are hidden,
  but only when Pixel Launcher is actually present.
- On first boot `service.sh` gives Pixel Launcher the home role.
- If the GSI already ships Pixel Launcher, the module uses that copy and drops its own.

## Checking on the phone

```bash
adb shell cmd overlay list android | grep cmftetris        # should show [x] for each
adb shell cmd overlay lookup android android:integer/config_defaultPeakRefreshRate
adb shell dumpsys display | grep -iE 'cutout|supportedModes'
adb shell dumpsys fingerprint | grep -i location
```

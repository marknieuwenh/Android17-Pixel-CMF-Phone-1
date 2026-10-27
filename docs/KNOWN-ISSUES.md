# Known issues and limits

Read this before flashing. A GSI swaps the whole Android framework on top of
Nothing's vendor code. Some features depend on code that only Nothing's own system
has, and no overlay can bring that back.

## Expected to work

The vendor HALs stay in place, so these normally work on a MediaTek GSI: display,
touch, Wi-Fi, Bluetooth, mobile data, SMS, GPS, sensors, audio, charging, and the
cameras through the stock camera HAL.

## Likely problems

### VoLTE / VoWiFi (calls on 4G)

On stock, MediaTek's IMS service ships in Nothing's `system_ext`, which the GSI
doesn't use. Without it, calls fall back to 2G/3G. **In countries where 2G/3G are
switched off or being switched off, voice calls may not work at all.** Test calls
right after flashing, and check whether your carrier still runs 2G or 3G.
This module can't fix it: the MediaTek IMS app needs MediaTek framework code
that the Google GSI doesn't include.

### Under-display fingerprint

The sensor position is carried over, but an optical under-display sensor also
needs the screen to light up a bright spot during a scan (high brightness mode).
Nothing implements that in its own SystemUI and vendor display code. On other custom
systems for this phone, users have reported the whole screen lighting up instead of
just the sensor area, and the fingerprint icon showing incorrectly.
Expect unlocks to be slower or less reliable than on stock, and keep a PIN.

### Display colours

The stock colour calibration and screen modes come from Nothing's display settings.
On other custom systems for this phone, users have reported oversaturated colours.
Settings → Display → Colors in the GSI offers the AOSP modes only.

### Camera quality

The cameras work through the stock HAL, but Nothing's image processing lives in
Nothing's camera app, so photos from the AOSP camera look flatter. Third-party camera
apps work, but don't expect stock quality.

### Play Integrity, banking and Google Wallet

An unlocked bootloader fails strong Play Integrity. Banking apps and Google Wallet
tap-to-pay may refuse to run. This can't be fixed reliably.

### Updates

Google's GSI doesn't get updates over the air. To update, flash a newer GSI
with `fastboot flash system` (data is kept unless you wipe), then rebuild the module
with a matching Pixel Launcher.

### Pixel-only launcher features

Some Pixel Launcher features rely on Pixel-only apps (Android System Intelligence,
Pixel Themes). With the GMS GSI, most of them work. Without it, the search bar,
At a Glance and the feed may be missing or empty.

## Not verified yet

Nobody has run this on a real CMF Phone 1 yet. Values like the refresh rate,
cutout and brightness come from your own stock dump, so they should match the
hardware, but whether Android 17 applies them correctly on this vendor still has to
be confirmed. Please report results with `tools/collect-logs.sh`.

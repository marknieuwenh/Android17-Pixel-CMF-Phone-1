# Magisk install-time script (sourced by Magisk's installer, do not run directly).

NEXUS_PKG=com.google.android.apps.nexuslauncher
FORCE_FLAG=/data/local/tmp/cmf-tetris-force

# --- Device check --------------------------------------------------------
# On a GSI the system-side props are generic, but the vendor partition is
# still Nothing's, so check the vendor props.
vdevice=$(getprop ro.product.vendor.device)
vmodel=$(getprop ro.product.vendor.model)
platform=$(getprop ro.board.platform)
ui_print "- Device: $vdevice / $vmodel / $platform, API $API"

case "$vdevice" in
  Tetris|tetris) ;;
  *)
    if [ "$platform" = "mt6878" ] || [ -f "$FORCE_FLAG" ]; then
      ui_print "! Vendor device is not Tetris, continuing because platform/force flag matches"
    else
      abort "! This module is only for the CMF Phone 1 (Tetris). Create $FORCE_FLAG to override."
    fi
    ;;
esac

[ "$API" -lt 37 ] && ui_print "! Android 17 (API 37) expected, found API $API. Pixel Launcher may crash."

# --- Pixel Launcher --------------------------------------------------------
bundled=false
[ -f "$MODPATH/system/product/priv-app/NexusLauncherRelease/NexusLauncherRelease.apk" ] && bundled=true

on_system=false
for d in /product/priv-app /system/product/priv-app /system_ext/priv-app /system/system_ext/priv-app; do
  for apk in "$d"/*/*.apk; do
    [ -f "$apk" ] || continue
    case "$apk" in
      *NexusLauncher*) on_system=true ;;
    esac
  done
done

if $bundled && $on_system; then
  ui_print "- The GSI already ships Pixel Launcher, using that copy"
  rm -rf "$MODPATH/system/product/priv-app/NexusLauncherRelease" \
         "$MODPATH/system/product/etc/permissions/privapp-permissions-nexuslauncher.xml"
  bundled=false
fi

if $bundled || $on_system; then
  ui_print "- Pixel Launcher will be the home and recents app"
  # Hide the GSI's own launchers so they don't compete for home/recents.
  # Never done without Pixel Launcher present, or the phone would have no launcher.
  for d in /system_ext/priv-app /product/priv-app /system/priv-app; do
    for name in Launcher3QuickStep Launcher3 Launcher3Go TrebuchetQuickStep; do
      if [ -d "$d/$name" ]; then
        case "$d" in
          /system/*) target="$MODPATH$d/$name" ;;
          *) target="$MODPATH/system$d/$name" ;;
        esac
        mkdir -p "$target"
        touch "$target/.replace"
        ui_print "  hiding $d/$name"
      fi
    done
  done
else
  ui_print "! Pixel Launcher not bundled and not on the GSI: keeping the GSI launcher."
  ui_print "  Rebuild the module with --pixel-launcher to add it."
  rm -rf "$MODPATH/system/product/overlay/PixelLauncherRecents" \
         "$MODPATH/system/product/etc/sysconfig/nexuslauncher-hiddenapi.xml"
fi

# --- Report what is being installed ---------------------------------------
for o in "$MODPATH"/system/product/overlay/*/; do
  [ -d "$o" ] && ui_print "- Overlay: $(basename "$o")"
done
[ -f "$MODPATH/stock-report.md" ] || ui_print "! No stock Nothing OS tuning included (built without stock/ dump)"

set_perm_recursive "$MODPATH" 0 0 0755 0644
set_perm "$MODPATH/service.sh" 0 0 0755

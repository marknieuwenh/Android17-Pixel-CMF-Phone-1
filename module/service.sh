#!/system/bin/sh
# Runs late in boot. One-time setup after the module is installed or updated.
MODDIR=${0%/*}
LOG="$MODDIR/service.log"
NEXUS_PKG=com.google.android.apps.nexuslauncher
STAMP="$MODDIR/.setup-done-$(grep '^versionCode=' "$MODDIR/module.prop" | cut -d= -f2)"

until [ "$(getprop sys.boot_completed)" = "1" ]; do sleep 2; done
sleep 5

[ -f "$STAMP" ] && exit 0

{
  echo "== $(date) first boot setup"
  if pm path "$NEXUS_PKG" >/dev/null 2>&1; then
    cmd role add-role-holder android.app.role.HOME "$NEXUS_PKG" 0 && echo "Pixel Launcher set as home app"
  else
    echo "Pixel Launcher not installed, home app left unchanged"
  fi
  cmd overlay list | grep -i -E 'cmftetris' || echo "No module overlays listed, check that they were mounted"
} >> "$LOG" 2>&1

touch "$STAMP"

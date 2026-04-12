#!/sbin/sh

### INSTALLATION ###

if [ "$BOOTMODE" != true ]; then
  ui_print "-----------------------------------------------------------"
  ui_print "! Please install in Magisk/KernelSU/APatch Manager"
  ui_print "! Install from recovery is NOT supported"
  abort "-----------------------------------------------------------"
fi

if [ "$KSU" = true ] && [ "$KSU_VER_CODE" -lt 10670 ]; then
  abort "ERROR: Please update your KernelSU and KernelSU Manager"
fi

if [ "$API" -lt 28 ]; then
  ui_print "! Unsupported sdk: $API"
  abort "! Minimal supported sdk is 28 (Android 9)"
else
  ui_print "- Device sdk: $API"
fi

# detect environment
if [ "$KSU" = true ]; then
  ui_print "- KernelSU version: $KSU_VER ($KSU_VER_CODE)"
elif [ "$APATCH" = true ]; then
  ui_print "- APatch detected"
else
  ui_print "- Magisk version: $MAGISK_VER ($MAGISK_VER_CODE)"
fi

ui_print "- Installing EasyTier for Magisk/KSU/APatch"

# data directory for config and runtime
if [ ! -d "/data/adb/easytier/config" ]; then
  mkdir -p /data/adb/easytier/config
  set_perm /data/adb/easytier 0 0 0755
fi

# install default config if not exists
if [ ! -f "/data/adb/easytier/config/config.toml" ]; then
  cp -f "$MODPATH/config.toml" /data/adb/easytier/config/
  touch /data/adb/easytier/.not_configured
  ui_print "- Default config installed to /data/adb/easytier/config/config.toml"
  ui_print "- ⚠ Please edit config before starting!"
else
  ui_print "- Existing config found, keeping it"
fi

# install default module settings if not exists
if [ ! -f "/data/adb/easytier/autostart.conf" ]; then
  echo "AUTO_START=1" > /data/adb/easytier/autostart.conf
  set_perm /data/adb/easytier/autostart.conf 0 0 0644
  ui_print "- Auto-start is enabled by default"
fi
rm -f "$MODPATH/config.toml"

# install binaries to module system/bin overlay
ui_print "- Installing binaries"
mkdir -p "$MODPATH/system/bin"
mv -f "$MODPATH/easytier-core" "$MODPATH/system/bin/"
mv -f "$MODPATH/easytier-cli" "$MODPATH/system/bin/"
mv -f "$MODPATH/easytier" "$MODPATH/system/bin/"

# permissions
ui_print "- Setting permissions"
set_perm_recursive "$MODPATH" 0 0 0755 0644
set_perm "$MODPATH/system/bin/easytier-core" 0 0 0755
set_perm "$MODPATH/system/bin/easytier-cli" 0 0 0755
set_perm "$MODPATH/system/bin/easytier" 0 0 0755

ui_print "- Installation complete, reboot your device"
ui_print "- Config: /data/adb/easytier/config/config.toml"
ui_print "- Manage: easytier {start|stop|restart|status}"

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
  root_framework=kernelsu
  ui_print "- KernelSU version: $KSU_VER ($KSU_VER_CODE)"
elif [ "$APATCH" = true ]; then
  root_framework=apatch
  ui_print "- APatch detected"
else
  root_framework=magisk
  ui_print "- Magisk version: $MAGISK_VER ($MAGISK_VER_CODE)"
fi

ui_print "- Installing EasyTier for Magisk/KSU/APatch"

# data directory for config and runtime
et_data="/data/adb/easytier"
if [ ! -d "$et_data/config" ]; then
  mkdir -p "$et_data/config"
  set_perm "$et_data" 0 0 0755
fi

printf '%s\n' "$root_framework" > "$et_data/root_framework" || abort "! Cannot save root framework"

# install default config if not exists
if [ ! -f "$et_data/config/config.toml" ]; then
  cp -f "$MODPATH/config.toml" "$et_data/config/"
  touch "$et_data/.not_configured"
  ui_print "- Default config installed to /data/adb/easytier/config/config.toml"
  ui_print "- ⚠ Please edit config before starting!"
else
  ui_print "- Existing config found, keeping it"
fi

# install default module settings if not exists
if [ ! -f "$et_data/autostart.conf" ]; then
  echo "AUTO_START=1" > "$et_data/autostart.conf"
  set_perm "$et_data/autostart.conf" 0 0 0644
  ui_print "- Auto-start is enabled by default"
fi
rm -f "$MODPATH/config.toml"

# Install the only permanent copies into the private data directory.
ui_print "- Installing private tools"
cp -f "$MODPATH/easytier-core" "$et_data/easytier-core" || abort "! Cannot install easytier-core"
cp -f "$MODPATH/easytier-cli" "$et_data/easytier-cli" || abort "! Cannot install easytier-cli"
cp -f "$MODPATH/easytier" "$et_data/easytier" || abort "! Cannot install easytier"
chmod 755 "$et_data/easytier-core" "$et_data/easytier-cli" "$et_data/easytier"
rm -f "$MODPATH/easytier-core" "$MODPATH/easytier-cli" "$MODPATH/easytier"

ui_print "- Setting permissions"
set_perm_recursive "$MODPATH" 0 0 0755 0644

# Mountless by default; preserve only an explicitly saved enabled choice.
mount_enabled=0
if [ -f "$et_data/mount_enabled" ]; then
  [ "$(cat "$et_data/mount_enabled")" = 1 ] && mount_enabled=1
  ui_print "- Preserving saved shell command mount choice"
else
  ui_print "- New installs and legacy upgrades default to NO shell command mount"
  ui_print "- After reboot, use full command paths; update scripts using short command names"
fi
printf '%s\n' "$mount_enabled" > "$et_data/mount_enabled" || abort "! Cannot save mount setting"
sh "$et_data/easytier" prepare-command-mount "$MODPATH" "$mount_enabled" || abort "! Cannot prepare command mount"
if [ "$mount_enabled" = 0 ]; then
  ui_print "- Shell command mount: disabled"
else
  ui_print "- Shell command mount: enabled"
fi
if [ "$(sh "$et_data/easytier" mount supported)" != 1 ]; then
  ui_print "- Shell command mount unavailable: no enabled mounting metamodule"
fi

ui_print "- Installation complete, reboot your device"
ui_print "- Config: /data/adb/easytier/config/config.toml"
ui_print "- Manage: /data/adb/easytier/easytier {start|stop|restart|status}"
ui_print "- Change shell command mount in WebUI (requires reboot)"

#!/system/bin/sh
# EasyTier boot-completed script (module script, NOT general script)
# Runs after boot is fully completed

MODDIR=${0%/*}

(
  until [ "$(getprop sys.boot_completed)" = "1" ]; do
    sleep 5
  done
  sleep 5
  # skip auto-start if not configured yet
  [ -f /data/easytier/.not_configured ] && exit 0
  # set hostname from instance_name in config
  hn=$(grep -m1 'instance_name' /data/easytier/config.toml 2>/dev/null | sed 's/.*=\s*"\(.*\)"/\1/')
  [ -n "$hn" ] && hostname "$hn"
  easytier start
)&

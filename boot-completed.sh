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
  hn=$(grep -m1 'instance_name' /data/easytier/config.toml 2>/dev/null | sed 's/.*= *"\(.*\)"/\1/')
  [ -n "$hn" ] && hostname "$hn"
  easytier start
  # update KSU description
  if command -v ksud >/dev/null 2>&1; then
    export KSU_MODULE="EasyTierForMagisk"
    sleep 1
    if pidof easytier-core >/dev/null 2>&1; then
      ip=$(grep -m1 'ipv4' /data/easytier/config.toml 2>/dev/null | sed 's/.*= *"\(.*\)"/\1/')
      ksud module config set override.description "✅ Running | IP: ${ip:-dhcp}" 2>/dev/null
    fi
  fi
)&

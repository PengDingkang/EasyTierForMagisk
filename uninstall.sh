#!/system/bin/sh
# Cleanup on module uninstall
# Note: /data/adb/easytier is kept intentionally to preserve user config

# kill running process
killall easytier-core 2>/dev/null

# remove data-dir fallback binaries while preserving user config
rm -f /data/adb/easytier/easytier-core
rm -f /data/adb/easytier/easytier-cli
rm -f /data/adb/easytier/easytier

#!/system/bin/sh
# Cleanup on module uninstall
# Note: /data/easytier is kept intentionally to preserve user config

# kill running process
killall easytier-core 2>/dev/null

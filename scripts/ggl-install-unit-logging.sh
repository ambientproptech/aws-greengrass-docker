#!/bin/sh
# Per-unit file logging under /greengrass/v2/logs/systemd/<unit>/service.log
#
# Dot-named units (ggl.core.iotcored, ggl.com.example.HelloLite) do not inherit
# ggl-.service.d dash-prefix drop-ins; install an explicit drop-in per unit.

set -e

unit=$1
[ -n "$unit" ] || exit 1

case "$unit" in
*.service) ;;
*) exit 0 ;;
esac

case "$unit" in
ggl.*|ggl-*|greengrass.service) ;;
*) exit 0 ;;
esac

dropdir="/etc/systemd/system/${unit}.d"
mkdir -p "$dropdir"
cat >"$dropdir/10-logging.conf" <<'EOF'
[Service]
ExecStartPre=+/bin/mkdir -p /greengrass/v2/logs/systemd/%n
StandardOutput=append:/greengrass/v2/logs/systemd/%n/service.log
StandardError=append:/greengrass/v2/logs/systemd/%n/service.log
EOF

#!/bin/sh
# Per-unit file logging under /greengrass/logs/systemd/<unit>/service.log
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

/usr/local/bin/ggl-ensure-unit-log-dir "$unit"

base=${unit%.service}
logdir="/greengrass/logs/systemd/${base}"
dropdir="/etc/systemd/system/${unit}.d"
mkdir -p "$dropdir"
cat >"$dropdir/10-logging.conf" <<EOF
[Service]
StandardOutput=append:${logdir}/service.log
StandardError=append:${logdir}/service.log
EOF

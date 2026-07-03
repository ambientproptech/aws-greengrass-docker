#!/bin/sh
# Create /greengrass/logs/systemd/<unit>/ before systemd opens StandardOutput paths.
# Directories must exist before the unit starts; ExecStartPre runs too late.

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

base=${unit%.service}
logdir="/greengrass/logs/systemd/${base}"
mkdir -p "$logdir"
chmod 755 "$logdir"

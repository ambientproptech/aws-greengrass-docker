#!/bin/sh
# Runtime nucleus bootstrap: core units pre-enabled at image build; component units
# reconciled from persisted unitPath before greengrass-lite.target starts.

set -e

echo "ggl-start-nucleus: preparing Greengrass Nucleus Lite units"
systemd-tmpfiles --create
systemctl reset-failed 2>/dev/null || true
systemctl daemon-reload
/usr/local/bin/ggl-reconcile-component-units
systemctl daemon-reload
echo "ggl-start-nucleus: starting greengrass-lite.target"
systemctl start --no-block greengrass-lite.target
echo "ggl-start-nucleus: greengrass-lite.target start requested"

#!/bin/sh
# Runtime nucleus bootstrap: core units pre-enabled at image build; component units
# reconciled from persisted rootPath before greengrass-lite.target starts.

set -e

systemd-tmpfiles --create
systemctl reset-failed 2>/dev/null || true
systemctl daemon-reload
/usr/local/bin/ggl-reconcile-component-units
systemctl daemon-reload
systemctl start --no-block greengrass-lite.target

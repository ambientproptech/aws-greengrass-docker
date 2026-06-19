#!/bin/sh
# Runtime nucleus bootstrap: units are pre-enabled at image build.

set -e

systemd-tmpfiles --create
systemctl reset-failed 2>/dev/null || true
systemctl daemon-reload
systemctl start --no-block greengrass-lite.target

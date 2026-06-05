#!/bin/sh

# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

set -e
set +m

if command -v findmnt >/dev/null 2>&1; then
	if findmnt -n /tmp 2>/dev/null | grep -q noexec; then
		echo "ERROR: /tmp must be mounted with exec permissions (not noexec)."
		exit 1
	fi
fi

if [ ! -f /etc/greengrass/config.yaml ] && [ -z "$(ls -A /etc/greengrass/config.d 2>/dev/null)" ]; then
	echo "WARNING: Mount config at /etc/greengrass/config.yaml or provide /etc/greengrass/config.d/*.yaml"
	echo "See https://github.com/aws-greengrass/aws-greengrass-lite/blob/main/docs/BUILD.md#optional-using-podman"
fi

if [ "$1" = "/lib/systemd/systemd" ]; then
	echo "Starting Greengrass Nucleus Lite (systemd PID 1; Podman is recommended per AWS docs)."
	exec /lib/systemd/systemd
fi

exec "$@"

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

# Lite reads /etc/greengrass/config.yaml (+ config.d). Balena/full images often mount
# /greengrass/v2 — wire that layout without requiring a second bind to /etc/greengrass.
link_lite_config() {
	src=$1
	dst=/etc/greengrass/config.yaml
	if [ ! -f "$src" ]; then
		return 1
	fi
	if [ -e "$dst" ] && [ "$(readlink -f "$dst")" = "$(readlink -f "$src")" ]; then
		echo "Using Greengrass config: $src"
		return 0
	fi
	if [ -e "$dst" ] && ! [ -L "$dst" ]; then
		echo "Using Greengrass config: $dst (mounted directly)"
		return 0
	fi
	ln -sf "$src" "$dst"
	echo "Using Greengrass config: $src -> $dst"
}

config_linked=false
if [ -f /etc/greengrass/config.yaml ] && ! [ -L /etc/greengrass/config.yaml ]; then
	echo "Using Greengrass config: /etc/greengrass/config.yaml (mounted directly)"
	config_linked=true
elif [ -n "${INIT_CONFIG}" ] && [ "${INIT_CONFIG}" != "default_init_config" ] && link_lite_config "${INIT_CONFIG}"; then
	config_linked=true
elif link_lite_config /greengrass/v2/config/config.yaml; then
	config_linked=true
fi

if [ -d /greengrass/v2/config.d ]; then
	for fragment in /greengrass/v2/config.d/*; do
		[ -f "$fragment" ] || continue
		name=$(basename "$fragment")
		dst="/etc/greengrass/config.d/$name"
		if [ -e "$dst" ]; then
			continue
		fi
		ln -sf "$fragment" "$dst"
		echo "Using Greengrass config fragment: $fragment -> $dst"
	done
fi

if [ "$config_linked" = false ] && [ -z "$(ls -A /etc/greengrass/config.d 2>/dev/null)" ]; then
	echo "WARNING: No Greengrass config found."
	echo "  Mount /greengrass/v2 (with config/config.yaml), or"
	echo "  /etc/greengrass/config.yaml, or set INIT_CONFIG to your config path."
	echo "See https://github.com/aws-greengrass/aws-greengrass-lite/blob/main/docs/BUILD.md#optional-using-podman"
fi

if [ "$1" = "/lib/systemd/systemd" ]; then
	echo "Starting Greengrass Nucleus Lite (systemd PID 1)."
	exec /lib/systemd/systemd
fi

exec "$@"

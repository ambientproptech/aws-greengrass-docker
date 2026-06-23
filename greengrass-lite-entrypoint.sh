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

# Lite reads /etc/greengrass/config.yaml (+ config.d). Balena/full images mount
# /greengrass/v2 — always prefer that path when present (over stale layer files).
config_src=""
if [ -n "${INIT_CONFIG}" ] && [ "${INIT_CONFIG}" != "default_init_config" ] && [ -f "${INIT_CONFIG}" ]; then
	config_src="${INIT_CONFIG}"
elif [ -f /greengrass/v2/config/config.yaml ]; then
	config_src="/greengrass/v2/config/config.yaml"
fi

if [ -n "$config_src" ]; then
	ln -sf "$config_src" /etc/greengrass/config.yaml
	echo "Using Greengrass config: $config_src -> /etc/greengrass/config.yaml"
elif [ -f /etc/greengrass/config.yaml ]; then
	echo "Using Greengrass config: /etc/greengrass/config.yaml"
else
	echo "WARNING: No Greengrass config found."
	echo "  Mount /greengrass/v2 (with config/config.yaml), or"
	echo "  /etc/greengrass/config.yaml, or set INIT_CONFIG to your config path."
	echo "See https://github.com/aws-greengrass/aws-greengrass-lite/blob/main/docs/BUILD.md#optional-using-podman"
fi

if [ -d /greengrass/v2/config.d ]; then
	for fragment in /greengrass/v2/config.d/*; do
		[ -f "$fragment" ] || continue
		name=$(basename "$fragment")
		dst="/etc/greengrass/config.d/$name"
		ln -sf "$fragment" "$dst"
	done
fi

# Lite daemons (iotcored, tesd, ggconfigd) run as ggcore; bind mounts often arrive root-owned.
if [ -d /greengrass/v2/certs ]; then
	if chown -R ggcore:ggcore /greengrass/v2/certs 2>/dev/null; then
		chmod 640 /greengrass/v2/certs/private.pem.key 2>/dev/null || true
		echo "Set ggcore ownership on /greengrass/v2/certs"
	fi
fi

if [ -d /var/lib/greengrass ]; then
	if chown -R ggcore:ggcore /var/lib/greengrass 2>/dev/null; then
		echo "Set ggcore ownership on /var/lib/greengrass (config.db and runtime state)"
	fi
fi

# Ensure Lite work dirs exist under bind mounts (recipes/packages/work only if not fully chowned above).
for gg_root in /var/lib/greengrass /greengrass/v2; do
	[ -d "$gg_root" ] || continue
	for sub in recipes packages work; do
		mkdir -p "$gg_root/$sub"
		chown ggcore:ggcore "$gg_root/$sub" 2>/dev/null || true
	done
done

# Component unit files persist under rootPath; ggl-reconcile-component-units (via
# ggl-container-init) re-links them into /etc/systemd/system on each boot.

# Per-unit log files (StandardOutput=append). systemd (root) creates/opens them
# before dropping to the service user, so the directory must exist and be on a
# writable mount — not :ro.
mkdir -p /greengrass/v2/logs/systemd
chmod 755 /greengrass/v2/logs/systemd

if [ "$1" = "/lib/systemd/systemd" ]; then
	echo "Starting Greengrass Nucleus Lite (systemd PID 1)."
	exec /lib/systemd/systemd
fi

exec "$@"

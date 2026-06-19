#!/bin/sh
# Bake systemd enable symlinks at image build (no running systemd required).
# Mirrors misc/run_nucleus from aws-greengrass-lite.

set -e

ENABLED_FILE=$(mktemp)
trap 'rm -f "$ENABLED_FILE"' EXIT

is_enabled() {
	grep -qxF "$1" "$ENABLED_FILE" 2>/dev/null
}

mark_enabled() {
	echo "$1" >>"$ENABLED_FILE"
}

link_unit() {
	unit=$1
	is_enabled "$unit" && return 0
	mark_enabled "$unit"

	path="/lib/systemd/system/$unit"
	if [ ! -f "$path" ]; then
		echo "missing unit: $path" >&2
		exit 1
	fi

	wanted=$(awk -F= '
		/^\[Install\]/ { in_install=1; next }
		/^\[/ { in_install=0 }
		in_install && /^WantedBy=/ { print $2 }
	' "$path")
	for target in $wanted; do
		mkdir -p "/etc/systemd/system/${target}.wants"
		ln -sf "$path" "/etc/systemd/system/${target}.wants/$unit"
	done

	also=$(awk -F= '
		/^\[Install\]/ { in_install=1; next }
		/^\[/ { in_install=0 }
		in_install && /^Also=/ { print $2 }
	' "$path")
	for other in $also; do
		link_unit "$other"
	done
}

for unit in \
	greengrass-lite.target \
	ggl.aws_iot_tes.socket \
	ggl.aws_iot_mqtt.socket \
	ggl.gg_config.socket \
	ggl.gg_health.socket \
	ggl.gg_fleet_status.socket \
	ggl.gg_deployment.socket \
	ggl.gg_pubsub.socket \
	ggl.ipc_component.socket \
	ggl.gg-ipc.socket.socket \
	ggl.core.ggconfigd.service \
	ggl.core.iotcored.service \
	ggl.core.tesd.service \
	ggl.core.ggdeploymentd.service \
	ggl.core.gg-fleet-statusd.service \
	ggl.core.ggpubsubd.service \
	ggl.core.gghealthd.service \
	ggl.core.ggipcd.service \
	ggl.aws.greengrass.TokenExchangeService.service
do
	link_unit "$unit"
done

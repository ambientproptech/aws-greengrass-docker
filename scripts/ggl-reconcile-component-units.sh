#!/bin/sh
# Re-register component systemd units from persisted rootPath after container recreate.
#
# Core nucleus units live in /lib/systemd/system (image). Component unit *files* are
# written under GGC_ROOT_PATH (/var/lib/greengrass, usually bind-mounted). The
# systemctl enable symlinks under /etc/systemd/system are ephemeral — recreate them
# on every boot before greengrass-lite.target starts.

set -e

ROOT="${GGC_ROOT_PATH:-/var/lib/greengrass}"
[ -d "$ROOT" ] || exit 0

linked=0
for unit in "$ROOT"/ggl.*.service; do
	[ -f "$unit" ] || continue
	base=$(basename "$unit")
	case "$base" in
	*.install.service) continue ;;
	ggl.core.*) continue ;;
	esac
	if systemctl link "$unit" >/dev/null 2>&1; then
		:
	else
		ln -sf "$unit" "/etc/systemd/system/$base"
	fi
	systemctl enable "$base" >/dev/null 2>&1 || true
	/usr/local/bin/ggl-install-unit-logging "$base"
	linked=$((linked + 1))
done

if [ "$linked" -gt 0 ]; then
	echo "ggl-reconcile-component-units: linked $linked component unit(s)"
	systemctl daemon-reload
fi

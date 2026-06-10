#!/bin/sh

# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

set -e
set +m

if command -v java >/dev/null 2>&1; then
	_j=$(command -v java)
	_j=$(readlink -f "$_j" 2>/dev/null || echo "$_j")
	JAVA_HOME=$(dirname "$(dirname "$_j")")
	export JAVA_HOME
	PATH="${JAVA_HOME}/bin:${PATH}"
	export PATH
fi

if command -v findmnt >/dev/null 2>&1; then
	if findmnt -n /tmp 2>/dev/null | grep -q noexec; then
		echo "ERROR: /tmp must be mounted with exec permissions (not noexec). AWS IoT Greengrass requirement."
		exit 1
	fi
fi

if [ -n "$(df -Pk / 2>/dev/null | awk 'NR==2 {print $4}')" ]; then
	avail_kb=$(df -Pk / | awk 'NR==2 {print $4}')
	if [ -n "$avail_kb" ] && [ "$avail_kb" -lt 262144 ] 2>/dev/null; then
		echo "WARNING: Less than 256 MiB free on /. AWS IoT Greengrass requires at least 256 MiB for Core software (excluding components)."
	fi
fi

INIT_JAR_PATH=/opt/greengrassv2
OPTIONS="-Droot=${GGC_ROOT_PATH} -Dlog.store=FILE -Dlog.level=${LOG_LEVEL} -jar ${INIT_JAR_PATH}/lib/Greengrass.jar --provision ${PROVISION} --deploy-dev-tools ${DEPLOY_DEV_TOOLS} --aws-region ${AWS_REGION} --setup-system-service true --start false"

parse_options() {

	if [ ${PROVISION} = "true" ]; then

		if [ ! -f "/root/.aws/credentials" ] && { [ -z "${AWS_ACCESS_KEY_ID}" ] || [ -z "${AWS_SECRET_ACCESS_KEY}" ]; }; then
			echo "Provision is set to true, but credentials not found, neither file exist at /root/.aws/credentials nor set in environment variables (AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, [AWS_SESSION_TOKEN]) . Please attach credentials and retry."
			exit 1
		fi

		if [ ${THING_NAME} != default_thing_name ]; then
		    OPTIONS="${OPTIONS} --thing-name ${THING_NAME}"
		fi
		if [ ${THING_GROUP_NAME} != default_thing_group_name ]; then
			OPTIONS="${OPTIONS} --thing-group-name ${THING_GROUP_NAME}"
		fi
               if [ ${THING_POLICY_NAME} != default_thing_policy_name ]; then
                       OPTIONS="${OPTIONS} --thing-policy-name ${THING_POLICY_NAME}"
               fi
	fi

	if [ ${TRUSTED_PLUGIN} != default_trusted_plugin_path ]; then
	  OPTIONS="${OPTIONS} --trusted-plugin ${TRUSTED_PLUGIN}"
	fi

	if [ ${TES_ROLE_NAME} != default_tes_role_name ]; then
		OPTIONS="${OPTIONS} --tes-role-name ${TES_ROLE_NAME}"
	fi

	if [ ${TES_ROLE_ALIAS_NAME} != default_tes_role_alias_name ]; then
		OPTIONS="${OPTIONS} --tes-role-alias-name ${TES_ROLE_ALIAS_NAME}"
	fi

	if [ ${COMPONENT_DEFAULT_USER} != default_component_user ]; then
		OPTIONS="${OPTIONS} --component-default-user ${COMPONENT_DEFAULT_USER}"
	fi

	if [ ${INIT_CONFIG} != default_init_config ]; then
		if [ -f ${INIT_CONFIG} ]; then
			echo "Using specified init config file at ${INIT_CONFIG}"
			OPTIONS="${OPTIONS} --init-config ${INIT_CONFIG}"
	    else
	    	echo "WARNING: Specified init config file does not exist at ${INIT_CONFIG} !"
	    fi
	fi

	echo "Running Greengrass with the following options: ${OPTIONS}"
}

ensure_greengrass_systemd_unit() {
	if [ ! -f /lib/systemd/system/greengrass.service ]; then
		cp /greengrass.service /lib/systemd/system/greengrass.service
	fi
	systemctl enable greengrass.service
}

if [ ! -d "$GGC_ROOT_PATH/alts/current/distro" ]; then
	echo "Installing Greengrass for the first time..."
	parse_options
	java ${OPTIONS}
	if [ $? -ne 0 ]; then
	  exit $?
	elif [ "${STARTUP}" = "false" ]; then
	  exit 0
	fi
else
	echo "Reusing existing Greengrass installation..."
fi

if [ ! -x "$GGC_ROOT_PATH/alts/current/distro/bin/loader" ]; then
	echo "Making loader script executable..."
	chmod +x "$GGC_ROOT_PATH/alts/current/distro/bin/loader"
fi

ensure_greengrass_systemd_unit

if [ "$1" = "/lib/systemd/systemd" ]; then
	echo "Starting Greengrass nucleus (systemd PID 1; greengrass.service enables OTA restarts)."
	exec /lib/systemd/systemd
fi

exec "$@"

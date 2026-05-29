# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

# --- Download stage: fetch and extract Greengrass (tools discarded after) ---
FROM debian:bookworm-slim AS downloader

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    wget \
    unzip \
    && rm -rf /var/lib/apt/lists/*

ARG GREENGRASS_RELEASE_VERSION=latest
ARG GREENGRASS_ZIP_FILE=greengrass-${GREENGRASS_RELEASE_VERSION}.zip
ARG GREENGRASS_RELEASE_URI=https://d2s8p88vqu9w66.cloudfront.net/releases/${GREENGRASS_ZIP_FILE}

RUN wget -q "$GREENGRASS_RELEASE_URI" -O "/tmp/${GREENGRASS_ZIP_FILE}" \
    && mkdir -p /opt/greengrassv2 \
    && unzip -q "/tmp/${GREENGRASS_ZIP_FILE}" -d /opt/greengrassv2 \
    && rm -f "/tmp/${GREENGRASS_ZIP_FILE}"

# --- Runtime stage: minimal image for running Greengrass ---
FROM debian:bookworm-slim

LABEL maintainer="AWS IoT Greengrass"
LABEL greengrass-version=${GREENGRASS_RELEASE_VERSION}
LABEL gg.base.os="debian-bookworm-slim"
LABEL gg.requirements.doc="https://docs.aws.amazon.com/greengrass/v2/developerguide/setting-up.html"
LABEL gg.endpoints.doc="https://docs.aws.amazon.com/general/latest/gr/greengrass.html"
LABEL gg.min-free-disk-mib="256"
LABEL gg.min-ggc-heap-mib="96"

ENV DEBIAN_FRONTEND=noninteractive

ENV TINI_KILL_PROCESS_GROUP=1 \
    GGC_ROOT_PATH=/greengrass/v2 \
    PROVISION=false \
    AWS_REGION=us-east-1 \
    THING_NAME=default_thing_name \
    THING_GROUP_NAME=default_thing_group_name \
    TES_ROLE_NAME=default_tes_role_name \
    TES_ROLE_ALIAS_NAME=default_tes_role_alias_name \
    COMPONENT_DEFAULT_USER=default_component_user \
    DEPLOY_DEV_TOOLS=false \
    INIT_CONFIG=default_init_config \
    TRUSTED_PLUGIN=default_trusted_plugin_path \
    THING_POLICY_NAME=default_thing_policy_name

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    sudo \
    procps \
    passwd \
    python3 \
    openjdk-17-jre-headless \
    awscli \
    coreutils \
    grep \
    util-linux \
    bash \
    debianutils \
    mount \
    tar \
    && rm -rf /var/lib/apt/lists/* \
    && dpkg-query -W libc6 \
    && dpkg --compare-versions "$(dpkg-query -W -f '${Version}' libc6)" ge 2.25 \
    && test -x "$(command -v java)" \
    && for c in ps sudo sh kill cp chmod rm ln id uname grep mkfifo aws findmnt useradd groupadd usermod echo; do command -v "$c" >/dev/null || exit 1; done

COPY --from=downloader /opt/greengrassv2 /opt/greengrassv2

RUN mkdir -p "${GGC_ROOT_PATH}"

COPY "greengrass-entrypoint.sh" /
RUN chmod +x /greengrass-entrypoint.sh

COPY "modify-sudoers.sh" /
RUN chmod +x /modify-sudoers.sh && ./modify-sudoers.sh && rm -f /modify-sudoers.sh

ENTRYPOINT ["/greengrass-entrypoint.sh"]

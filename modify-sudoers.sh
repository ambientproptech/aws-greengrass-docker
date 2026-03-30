#!/bin/sh

# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

# Allow the root user to execute commands as other users

set -e

run() {
  if [ "$(id -u)" -eq 0 ]; then
    "$@"
  else
    sudo "$@"
  fi
}

ROOT_LINE_NUM=$(grep -n "^root" /etc/sudoers | cut -d : -f 1)

if run sed -n "${ROOT_LINE_NUM}p" /etc/sudoers | grep -q "ALL=(ALL:ALL)" ; then
  echo "Root user is already configured to execute commands as other users."
  exit 0
fi

echo "Attempting to safely modify /etc/sudoers..."

run cp /etc/sudoers /tmp/sudoers.bak

run sed -i "$ROOT_LINE_NUM s/ALL=(ALL)/ALL=(ALL:ALL)/" /tmp/sudoers.bak

if run visudo -cf /tmp/sudoers.bak; then
  run mv /tmp/sudoers.bak /etc/sudoers
  echo "Successfully modified /etc/sudoers. Root user is now configured to execute commands as other users."
else
  echo "Error while trying to modify /etc/sudoers, please edit manually."
  exit 1
fi

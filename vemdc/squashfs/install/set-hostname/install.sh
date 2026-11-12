#!/usr/bin/env bash

INSTALL_DIR=/install

cp ${INSTALL_DIR}/set-hostname/set-hostname.sh /usr/local/sbin/set-hostname.sh
cp ${INSTALL_DIR}/set-hostname/set-hostname.service /etc/systemd/system/set-hostname.service

chmod +x /usr/local/sbin/set-hostname.sh
systemctl enable set-hostname.service
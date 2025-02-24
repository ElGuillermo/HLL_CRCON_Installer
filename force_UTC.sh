#!/bin/bash

if command -v apt &> /dev/null; then
    INSTALL_CMD="apt update && apt install -y systemd-timesyncd"
elif command -v dnf &> /dev/null; then
    INSTALL_CMD="dnf install -y systemd-timesyncd"
elif command -v yum &> /dev/null; then
    INSTALL_CMD="yum install -y systemd-timesyncd"
elif command -v zypper &> /dev/null; then
    INSTALL_CMD="zypper install -y systemd-timesyncd"
elif command -v pacman &> /dev/null; then
    INSTALL_CMD="pacman -Sy --noconfirm systemd-timesyncd"
else
    echo "Unsupported package manager. Please install systemd-timesyncd manually."
    exit 1
fi

eval $INSTALL_CMD
systemctl start systemd-timesyncd
systemctl enable --now systemd-timesyncd
timedatectl set-ntp true
timedatectl set-timezone UTC
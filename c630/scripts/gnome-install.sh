#!/bin/sh
# GNOME (gnome-core, without plymouth) + Google Chrome arm64 on the C630.
# Run as root: systemd-run --unit=gnome-chrome-install sh gnome-install.sh
# Prerequisite: /etc/apt/preferences.d/no-plymouth (pins plymouth to -1).
set -e
export DEBIAN_FRONTEND=noninteractive
O="-o Dpkg::Options::=--force-confdef -o Dpkg::Options::=--force-confold"
apt-get -y $O install gnome-core
cd /tmp && rm -f google-chrome-stable_current_arm64.deb
wget -q https://dl.google.com/linux/direct/google-chrome-stable_current_arm64.deb
dpkg-deb -f google-chrome-stable_current_arm64.deb Package Version Architecture
apt-get -y $O install ./google-chrome-stable_current_arm64.deb
echo "ALL DONE"

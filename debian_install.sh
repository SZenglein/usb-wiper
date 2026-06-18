#!/bin/sh

set -euxo pipefail

# --- Install dependencies ---

apt update
apt install -y util-linux parted dosfstools

# --- Install main script ---

install -m 0755 usb-wiper-ui.sh /usr/local/bin/usb-wiper-ui.sh

# --- Install systemd service ---

install -m 0644 usb-wiper-ui.service /etc/systemd/system/usb-wiper-ui.service

systemctl daemon-reload
systemctl enable usb-wiper-ui.service

# --- Create udev rule ---

cat <<EOF > /etc/udev/rules.d/99-usb-wipe.rules
ACTION=="add", SUBSYSTEM=="block", ENV{ID_BUS}=="usb", ATTR{removable}=="1", RUN+="/bin/sh -c 'echo /dev/%k > /tmp/usb-wiper-events'"
EOF

# --- Reload systemd + udev ---

systemctl daemon-reexec
systemctl daemon-reload
udevadm control --reload

# --- Ensure UI is visible on tty1 ---

systemctl disable getty@tty1 

# Login backdoor
systemctl enable getty@tty2

echo "Installation complete"
echo "Reboot the system to apply changes"


#!/bin/sh

set -euo pipefail

FIFO="/tmp/usb-wiper-events"

# Create FIFO if not exists

[ -p "$FIFO" ] || mkfifo "$FIFO"

show() {
	clear
	echo "=============================="
	echo "      USB SANITIZER"
	echo "=============================="
	echo
	echo "$1"
}

wipe_device() {
	DEVICE="$1"

	$()$(
		BASENAME=$(basename "$DEVICE")

		# Safety check: removable only
		if [ "$(cat /sys/block/$BASENAME/removable)" != "1" ]; then
			show "❌ Skipped non-removable: $DEVICE"
			sleep 2
			return
		fi

		show "🔵 Detected: $DEVICE"
		sleep 1

		show "Wiping signatures..."
		wipefs -a "$DEVICE"

		show "Zeroing headers..."
		dd if=/dev/zero of="$DEVICE" bs=1M count=10 status=none

		show "Partitioning..."
		parted -s "$DEVICE" mklabel msdos
		parted -s "$DEVICE" mkpart primary fat32 1MiB 100%

		show "Formatting..."
		mkfs.vfat -F 32 "${DEVICE}1"

		show "🟢 DONE: $DEVICE\nSafe to remove"
		sleep 3
	)$()

}

# Startup screen

show "🟡 Insert USB drive..."

# Main loop

while true; do
	if read DEVICE <"$FIFO"; then
		wipe_device "$DEVICE"
		show "🟡 Insert USB drive..."
	fi
done

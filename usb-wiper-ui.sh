#!/bin/sh

set -u

trap '' INT TERM TSTP QUIT

dmesg -n 1
stty -echo

FIFO="/run/usb-wiper-events"

show() {
	clear
	echo "=============================="
	echo "      USB SANITIZER"
	echo "=============================="
	echo
	echo "$1"
}

show_next() {
	echo "=============================="
	echo
	echo "$1"
}

wipe_device() {
	DEVICE="$1"

	BASENAME=$(basename "$DEVICE")

	# Safety check: removable only
	if [ "$(cat /sys/block/$BASENAME/removable)" != "1" ]; then
		show "❌ Skipped non-removable: $DEVICE"
		sleep 2
		return
	fi

	show "🔵 Detected: $DEVICE"
	sleep 1

	show_next "Wiping signatures..."
	if ! wipefs -a "$DEVICE"; then
		show_next "❌ Failed to wipe signatures"
		sleep 3
		return
	fi

	show_next "Zeroing headers..."
	if ! dd if=/dev/zero of="$DEVICE" bs=1M count=10 status=none; then
		show_next "❌ Failed to zero device"
		sleep 3
		return
	fi

	show_next "Partitioning..."
	if ! parted -s "$DEVICE" mklabel msdos; then
		show_next "❌ Failed to create partition table"
		sleep 3
		return
	fi

	if ! parted -s "$DEVICE" mkpart primary fat32 1MiB 100%; then
		show_next "❌ Failed to create partition"
		sleep 3
		return
	fi

	sleep 1

	show_next "Formatting..."
	if ! mkfs.vfat -F 32 "${DEVICE}1"; then
		show_next "❌ Failed to format partition"
		sleep 3
		return
	fi

	show_next "🟢 DONE: $DEVICE\nSafe to remove"
	sleep 10
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

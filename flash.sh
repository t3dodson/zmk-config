#/usr/bin/env bash

if [[ $EUID -ne 0 ]]; then
	echo "This script requires root"
	exit 1
fi

SCRIPT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

U2F_PATH="${SCRIPT_ROOT%/}/$1"
MOUNT_POINT=/mnt

if [[ ! -e $U2F_PATH ]]; then
	echo "$U2F_PATH doesn't exist"
	exit 1
fi

FD=/dev/disk/by-label/NICENANO

SLEEP_TIME=2

echo "Flashing script, assumes that $FD is our target flashpoint. Sleep time is $SLEEP_TIME seconds"

echo "Put the keyboard into bootloader mode (plugin, double click power button)"
while true; do
	sleep $SLEEP_TIME
	if [[ ! -e $FD ]]; then
		echo "Waiting for $FD so we can flash $U2F_PATH"
		continue
	fi
	echo "Mounting $FD to $MOUNT_POINT"
	mount $FD $MOUNT_POINT	

	echo "about to flash"
	sleep $SLEEP_TIME
	echo "flashing"
	cp $U2F_PATH $FD

	umount $FD
	break
done
echo "Done Flashing $FD with $U2F_PATH"


#!/bin/sh
# NOTE: becomes .tmp_update/my282.sh

PLATFORM="my282"
SDCARD_PATH="/mnt/SDCARD"
UPDATE_PATH="$SDCARD_PATH/MinUI.zip"
SYSTEM_PATH="$SDCARD_PATH/.system"

CPU_PATH=/sys/devices/system/cpu/cpu0/cpufreq/scaling_governor
echo performance > "$CPU_PATH"

# install/update
if [ -f "$UPDATE_PATH" ]; then
	cd $(dirname "$0")/$PLATFORM

	if [ -d "$SYSTEM_PATH" ]; then
		./show.elf ./updating.png
	else
		./show.elf ./installing.png
	fi

	mv $SDCARD_PATH/.tmp_update $SDCARD_PATH/.tmp_update-old
	./unzip -o "$UPDATE_PATH" -d "$SDCARD_PATH"
	rm -f "$UPDATE_PATH"
	rm -rf $SDCARD_PATH/.tmp_update-old

	# the updated system finishes the install/update
	$SYSTEM_PATH/$PLATFORM/bin/install.sh
fi

# or launch (and keep launched)
LAUNCH_PATH="$SYSTEM_PATH/$PLATFORM/paks/MinUI.pak/launch.sh"
while [ -f "$LAUNCH_PATH" ] ; do
	"$LAUNCH_PATH"
done

poweroff # under no circumstances should stock be allowed to touch this card

#!/usr/bin/env sh

ASOUND=/var/lib/alsa/asound.state
ASOUND_NEW="$ASOUND".new

# Don't modify the file if we don't need to
if ! grep -q "state.$1 " "$ASOUND"
then
    # Make sure ALSA sees this card
    while [ $((`aplay -l | grep -c "$1"`)) -lt 1 ]
    do
        sleep .5
    done

    # Find the hardware number
    DEVNUM=`aplay -l | grep "$1" | grep -o -E "card \w" | cut -d ' ' -f 2`

    # In legacy asound.state files, card 0 had a device name
    # of "Device" and card 1 had a device name of "Device_1"
    if [ "$DEVNUM" = "0" ]
    then
        DEVNAME="Device"
    else
        DEVNAME="Device_1"
    fi

    # Rewrite the asound.state with the new device name
    sed -e "s/state.$DEVNAME /state.$1 /g" < "$ASOUND" > "$ASOUND_NEW" && mv "$ASOUND_NEW" "$ASOUND"
fi

alsactl restore

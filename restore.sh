#!/usr/bin/env sh

ASOUND=/var/lib/alsa/asound.state
ASOUND_NEW="$ASOUND".new

for DEVICE in "$@"
do
    # Don't modify the file if we don't need to
    if ! grep -q "state.$DEVICE " "$ASOUND"
    then
        # Make sure ALSA sees this card
        while [ $((`aplay -l | grep -c "$DEVICE"`)) -lt 1 ]
        do
            sleep .5
        done

        # Here we try to handle a couple scenarios:
        # 1. The user has done a static assignment of audio devices but has
        #    not updated the asound.state file
        # 2. The user has not done a static assignment of audio devices and
        #    has not updated the asound.state file
        #
        # In the former case the crypto.ini file will tell us which device
        # we are, and we can do the mapping clean. The latter case is "dirty",
        # but no dirtier than it ever was.

        # Determine if the crypto.ini file has a static assignment
        if iniget JACK VoiceDevice /etc/crypto.ini.sd | grep -q "USB" && \
           iniget JACK ModemDevice /etc/crypto.ini.sd | grep -q "USB"
        then
            # Check the crypto.ini to see if this is the voice device
            if iniget JACK VoiceDevice /etc/crypto.ini.sd | grep -q "$DEVICE"
            then
                # If it is, then it is "card 0" by definition
                DEVNUM="0"
            # Check the crypto.ini to see if this is the modem device
            elif iniget JACK ModemDevice /etc/crypto.ini.sd | grep -q "$DEVICE"
            then
                # If it is, then it is "card 1" by definition
                DEVNUM="1"
            # Otherwise this isn't a mapped device. This either indicates
            # a configuration error or more than two audio devices installed
            # in the system. Bail in either case
            else
                continue
            fi
        # Otherwise, assume that the device numbers are stable and use the
        # current device number. Normally this assumption holds true, and
        # is the assumption that the system used to use.
        else
            # Find the hardware number
            DEVNUM=`aplay -l | grep "$DEVICE" | grep -o -E "card \w" | cut -d ' ' -f 2`
        fi

        # In legacy asound.state files, card 0 had a device name
        # of "Device" and card 1 had a device name of "Device_1"
        if [ "$DEVNUM" = "0" ]
        then
            DEVNAME="Device"
        else
            # If there are more than two audio devices installed things can
            # get messed up, so try to avoid that
            DEVNAME="Device_$DEVNUM"
        fi

        # Rewrite the asound.state with the new device name
        sed -e "s/state.$DEVNAME /state.$DEVICE /g" < "$ASOUND" > "$ASOUND_NEW" && mv "$ASOUND_NEW" "$ASOUND"
    fi
done

alsactl restore

#!/usr/bin/env sh

while [ $((`aplay -l | grep -c card`)) -lt 2 ]
do
    sleep .5
done

while [ true ]
do
    clear
    read -p 'Type "0" for headset, "1" for radio, or "s" to save and press Enter: ' option
    case "$option" in
        0)
            alsamixer -c 0
            ;;
        1)
            alsamixer -c 1
            ;;
        s)
            alsactl store && mcopy -t -D o -i /dev/mmcblk0p1 /var/lib/alsa/asound.state ::config/asound.state
            ;;
        *)
            "Invalid option"
            ;;
    esac
done


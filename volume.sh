#!/usr/bin/env sh

. /etc/profile.d/shell_functions.sh

adjust_volume()
{
    amixer -D "$2" sset Speaker "$1" && \
        cp /usr/share/sounds/beep.wav "$NOTIFY_FILE" && \
        /etc/init.d/S31jack_crypto_rx signal SIGUSR1
}

while read -r command
do
    HEADSET=`get_sound_hw_device VoiceDevice`
    case "$command" in
        up)
            adjust_volume '10%+' "$HEADSET";
            ;;
        down)
            adjust_volume '10%-' "$HEADSET";
            ;;
    esac
done

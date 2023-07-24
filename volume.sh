#!/usr/bin/env sh

. /etc/profile.d/shell_functions.sh

HEADSET=`get_sound_hw_device VoiceDevice`

adjust_volume()
{
    amixer -D "$HEADSET" sset Speaker "$1" && \
        cp /usr/share/sounds/beep.wav "$NOTIFY_FILE" && \
        /etc/init.d/S31jack_crypto_rx signal SIGUSR1
}

case "$1" in
    up)
        adjust_volume '10%+';
        ;;
    down)
        adjust_volume '10%-';
        ;;
    *)
        echo "usage: volume.sh <up|down>" >&2
        ;;
esac

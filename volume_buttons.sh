#!/usr/bin/env sh
trap "kill %1; exit 0" INT TERM

. /etc/profile.d/shell_functions.sh

wait_initialized

HEADSET=`get_sound_hw_device VoiceDevice`
UP=`get_config_val Volume UpGPIONum`
DOWN=`get_config_val Volume DownGPIONum`
BIAS=`get_config_val Volume Bias`
ACTIVE=`get_config_val Volume ActiveLow`

if test "$ACTIVE" -ne 0
then
    LOW_ARG="-l"
fi

edge_detect()
{
    gpiomon $LOW_ARG -B "$BIAS" -r -F '%o' -n 1 gpiochip0 "$UP" "$DOWN" &
    wait
}

debounce()
{
    COUNT=0
    for i in `seq 1 8`
    do
        if test `gpioget $LOW_ARG -B "$BIAS" gpiochip0 "$1"` -eq 1
        then
            COUNT=$((COUNT+1))
        fi
    done

    test $COUNT -gt 4
}

while edge_detect > /tmp/volume
do
    PIN=`cat /tmp/volume`

    if debounce "$PIN"
    then
        case "$PIN" in
            "$UP")
                VOL='10%+'
                ;;
            "$DOWN")
                VOL='10%-'
                ;;
        esac

        test -n "$VOL" && amixer -D "$HEADSET" sset Speaker "$VOL" && \
            cp /usr/share/sounds/beep.wav /tmp/notify.wav && \
            /etc/init.d/S31jack_crypto_rx signal SIGUSR1 && \
            sleep .1
    fi
done

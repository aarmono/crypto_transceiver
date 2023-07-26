#!/usr/bin/env sh

. /etc/profile.d/shell_functions.sh

send_alert()
{
    ALERT=`get_config_val TTS "$1"`
    test -n "$ALERT" && execute_alert_broadcast "$ALERT"
}

reset_key_idx()
{
    get_config_val Crypto KeyIndex
}

next_key_idx()
{
    NEXT_KEY_IDX=$((KEY_IDX+1))
    while ! has_key "$NEXT_KEY_IDX"
    do
        if test "$NEXT_KEY_IDX" -ge 256
        then
            NEXT_KEY_IDX=1
        else
            NEXT_KEY_IDX=$((NEXT_KEY_IDX+1))
        fi
    done

    echo "$NEXT_KEY_IDX"
}

update_key_idx()
{
    if set_config_val Crypto KeyIndex "$1"
    then
        /etc/init.d/S30jack_crypto_tx signal SIGHUP
        /etc/init.d/S31jack_crypto_rx signal SIGHUP
        headset_tts "$1 Confirm"
    fi
}

toggle_digital()
{
    DIGITAL_EN=`get_config_val Codec Enabled`
    DIGITAL_EN=$((DIGITAL_EN^1))
    if set_config_val Codec Enabled "$DIGITAL_EN"
    then
        /etc/init.d/S30jack_crypto_tx signal SIGHUP
        /etc/init.d/S31jack_crypto_rx signal SIGHUP
        if test "$DIGITAL_EN" -ne 0
        then
            CRYPTO_EN=`get_config_val Crypto Enabled`
            if test "$CRYPTO_EN" -ne 0
            then
                headset_tts "Secure"
            else
                headset_tts "Digital"
            fi
        else
            headset_tts "Plain"
        fi
    fi
}

adjust_volume()
{
    amixer -q -D "$HEADSET" sset Speaker "$1" && \
        cp /usr/share/sounds/beep.wav "$NOTIFY_FILE" && \
        /etc/init.d/S31jack_crypto_rx signal SIGUSR1
}

KEY_IDX=`reset_key_idx`
HEADSET=`get_sound_hw_device VoiceDevice`

while read -r button event
do
    case "$event" in
        alert)
            case "$button" in
                a)
                    send_alert Alert1
                    ;;
                b)
                    send_alert Alert2
                    ;;
             esac
             ;;
        reset)
            case "$button" in
                a)
                    KEY_IDX=`reset_key_idx`
                    ;;
            esac
            ;;
        select)
            case "$button" in
                a)
                    headset_tts "Key Select"
                    ;;
            esac
            ;;
        value)
            case "$button" in
                a)
                    headset_tts "$KEY_IDX"
                    ;;
            esac
            ;;
        incr)
            case "$button" in
                a)
                    KEY_IDX=`next_key_idx "$KEY_IDX"`
                    ;;
            esac
            ;;
        update)
            case "$button" in
                a)
                    update_key_idx "$KEY_IDX"
                    ;;
                d)
                    toggle_digital
                    ;;
                up)
                    adjust_volume '10%+'
                    ;;
                down)
                    adjust_volume '10%-'
                    ;;
            esac
            ;;
    esac
done

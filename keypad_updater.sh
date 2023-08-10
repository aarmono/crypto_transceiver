#!/usr/bin/env sh

. /etc/profile.d/shell_functions.sh

send_alert()
{
    ALERT=`get_config_val TTS "$1"`
    test -n "$ALERT" && execute_alert_broadcast "$ALERT"
}

reset_key_idx()
{
    get_key_index
}

# $1: Key Index to select
# $2: Confirm message (optional)
update_key_idx()
{
    if test -n "$2"
    then
        CONFIRM_MSG="$2"
    else
        CONFIRM_MSG="$1 Selected"
    fi

    if set_key_index "$1"
    then
        # Reverse order SIGHUP to give RX more time
        # to reinitialize before playing TTS
        /etc/init.d/S31jack_crypto_rx signal SIGHUP
        /etc/init.d/S30jack_crypto_tx signal SIGHUP

        if has_key "$1"
        then
            headset_tts "$CONFIRM_MSG"
        else
            headset_tts "No Key"
        fi
    else
        headset_tts "Error"
    fi
}

load_keys()
{
    if load_sd_key_noclobber
    then
        /etc/init.d/manual/S10pppoe_client stop

        KEY_IDX=`next_key_idx 256`
        update_key_idx "$KEY_IDX" "Loaded. Key $KEY_IDX Selected"

        ifconfig eth0 down
    else
        /etc/init.d/manual/S10pppoe_client stop

        headset_tts "Error"

        ifconfig eth0 down
    fi
}

toggle_digital()
{
    DIGITAL_EN=`get_config_val Codec Enabled`
    DIGITAL_EN=$((DIGITAL_EN^1))
    if set_config_val Codec Enabled "$DIGITAL_EN"
    then
        # Reverse order SIGHUP to give RX more time
        # to reinitialize before playing TTS
        /etc/init.d/S31jack_crypto_rx signal SIGHUP
        /etc/init.d/S30jack_crypto_tx signal SIGHUP
        CRYPTO_EN=`get_config_val Crypto Enabled`
        if test "$DIGITAL_EN" -ne 0
        then
            if test "$CRYPTO_EN" -ne 0
            then
                KEY_IDX=`get_key_index`
                if has_key "$KEY_IDX"
                then
                    headset_tts "Secure"
                else
                    headset_tts "No Key"
                fi
            else
                headset_tts "Digital"
            fi
        else
            if test "$CRYPTO_EN" -ne 0
            then
                headset_tts "Plain"
            else
                headset_tts "Analog"
            fi
        fi
    else
        headset_tts "Error"
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
                b)
                    /etc/init.d/manual/S10pppoe_client stop
                    ifconfig eth0 down
                    ;;
            esac
            ;;
        select)
            case "$button" in
                a)
                    KEY_IDX=`reset_key_idx`
                    headset_tts "Key Select"
                    ;;
                b)
                    if ! has_any_keys
                    then
                        ifconfig eth0 up
                    fi
                    headset_tts "Key Load"
                    ;;
            esac
            ;;
        value)
            case "$button" in
                a)
                    headset_tts "$KEY_IDX"
                    ;;
                b)
                    if ! has_any_keys && ext_has_any_keys
                    then
                        /etc/init.d/manual/S10pppoe_client start
                        headset_tts "Ready to Load"
                    else
                        headset_tts "Cannot Load"
                    fi
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
                b)
                    if ! has_any_keys && ext_has_any_keys
                    then
                        load_keys
                    else
                        headset_tts "Cannot Load"
                    fi
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

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
    NEXT_KEY_IDX=$(($1+1))
    # Prevent infinite loop if no key
    while test "$NEXT_KEY_IDX" -ne "$1" && ! has_key "$NEXT_KEY_IDX"
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

    if set_config_val Crypto KeyIndex "$1"
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

lock_display()
{
    CONFIGURE_PID=`ps -A | grep 'configure.sh' | grep -v grep | sed -E 's/^ +//g' | cut -d ' ' -f 1`
    test -n "$CONFIGURE_PID" && kill "$CONFIGURE_PID" && killall -9 dialog
}

load_keys()
{
    if load_sd_key_noclobber
    then
        KEY_IDX=`next_key_idx 0`
        update_key_idx "$KEY_IDX" "Loaded. Key $KEY_IDX Selected"
        lock_display
    else
        headset_tts "Error"
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
                KEY_IDX=`get_config_val Crypto KeyIndex`
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
            esac
            ;;
        select)
            case "$button" in
                a)
                    KEY_IDX=`reset_key_idx`
                    headset_tts "Key Select"
                    ;;
                b)
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
                    if sd_has_any_keys && ! has_any_keys
                    then
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
                    if sd_has_any_keys && ! has_any_keys
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

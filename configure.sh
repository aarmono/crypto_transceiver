#!/usr/bin/env sh

. /etc/profile.d/shell_functions.sh

exec 2>/dev/null
set -o pipefail

ANSWER=/tmp/answer
SD_IMG=/tmp/sd.img
# "Dirty" just means the jack_crypto_tx and jack_crypto_rx services
# need to be SIGHUP-ed
# "Filthy" means the audio services need to be restarted
DIRTY=/tmp/dirty
FILTHY=/tmp/filthy

alias set_dirty="touch $DIRTY"
alias set_filthy="touch $FILTHY"
alias disable_config="set_config_val Config Enabled 0"

trap 'disable_config; exit 0' INT TERM EXIT

on_off()
{
    test "$1" = "$2" && echo on || echo off
}

on_off_checklist()
{
    if echo "$1" | grep -q "$2"
    then
        echo on
    else
        echo off
    fi
}

# Generic function to display a On/Off/Default radiolist
# $1: Config Section
# $2: Config Key
# $3: Title
# $4: Off text (optional)
# $5: On text (optional)
dialog_on_off_default()
{
    if test -z "$4"
    then
        OFF="Off"
    else
        OFF="$4"
    fi

    if test -z "$5"
    then
        ON="On"
    else
        ON="$5"
    fi

    while true
    do
        if is_initialized
        then
            VAL=`get_user_config_val "$1" "$2"`
            DEFAULT=`get_sys_config_val "$1" "$2"`

            if test "$DEFAULT" = "0"
            then
                DEFAULT="$OFF"
            else
                DEFAULT="$ON"
            fi

            dialog \
            --no-tags \
            --title "$3" \
            --radiolist "Select an option or \"Default\" to use the system default." 10 60 4 \
            default "Default ($DEFAULT)" `on_off $VAL ""` \
            1       "$ON"                `on_off $VAL 1`  \
            0       "$OFF"               `on_off $VAL 0` 2>$ANSWER

            option=`cat $ANSWER`
            case "$option" in
                default)
                    set_config_val "$1" "$2" ""
                    set_dirty
                    ;;
                0|1)
                    set_config_val "$1" "$2" $option
                    set_dirty
                    ;;
            esac

            return
        elif ! dialog --yesno "Config Not Initialized! Retry?" 0 0
        then
            return
        fi
    done
}

configure_ptt_enable()
{
    dialog_on_off_default PTT Enabled "Enable Push to Talk"
}

# $1: Direction (ie. Input/Output)
# $2: Config Section
# $3: Config Key
# $4: 1 to display Console option (optional)
# $5: Pin Description (optional)
assign_pin()
{
    VAL=`get_user_config_val $2 $3`
    DEFAULT=`get_sys_config_val $2 $3`

    PIN_DESC="$2 $1"
    if test -n "$5"
    then
        PIN_DESC="$5"
    fi

    HEIGHT=36
    CONSOLE_ARGS=`mktemp`
    if test "$4" -eq 1
    then
        echo "console \"Console Interface\" `on_off $VAL "-1"`" >> "$CONSOLE_ARGS"
        HEIGHT=$((HEIGHT+1))
    fi

    dialog \
    --no-tags \
    --title "Configure $PIN_DESC Pin (See: https://pinout.xyz)" \
    --radiolist "Select an option or \"Default\" to use the system default." "$HEIGHT" 60 4 \
    default "Default (GPIO $DEFAULT)" `on_off $VAL ""` \
    --file "$CONSOLE_ARGS"                             \
    0       "GPIO 0"                  `on_off $VAL 0`  \
    1       "GPIO 1"                  `on_off $VAL 1`  \
    2       "GPIO 2"                  `on_off $VAL 2`  \
    3       "GPIO 3"                  `on_off $VAL 3`  \
    4       "GPIO 4"                  `on_off $VAL 4`  \
    5       "GPIO 5"                  `on_off $VAL 5`  \
    6       "GPIO 6"                  `on_off $VAL 6`  \
    7       "GPIO 7"                  `on_off $VAL 7`  \
    8       "GPIO 8"                  `on_off $VAL 8`  \
    9       "GPIO 9"                  `on_off $VAL 9`  \
    10      "GPIO 10"                 `on_off $VAL 10` \
    11      "GPIO 11"                 `on_off $VAL 11` \
    12      "GPIO 12"                 `on_off $VAL 12` \
    13      "GPIO 13"                 `on_off $VAL 13` \
    14      "GPIO 14"                 `on_off $VAL 14` \
    15      "GPIO 15"                 `on_off $VAL 15` \
    16      "GPIO 16"                 `on_off $VAL 16` \
    17      "GPIO 17"                 `on_off $VAL 17` \
    18      "GPIO 18"                 `on_off $VAL 18` \
    19      "GPIO 19"                 `on_off $VAL 19` \
    20      "GPIO 20"                 `on_off $VAL 20` \
    21      "GPIO 21"                 `on_off $VAL 21` \
    22      "GPIO 22"                 `on_off $VAL 22` \
    23      "GPIO 23"                 `on_off $VAL 23` \
    24      "GPIO 24"                 `on_off $VAL 24` \
    25      "GPIO 25"                 `on_off $VAL 25` \
    26      "GPIO 26"                 `on_off $VAL 26` \
    27      "GPIO 27"                 `on_off $VAL 27` 2>$ANSWER

    rm "$CONSOLE_ARGS"

    option=`cat $ANSWER`
    case "$option" in
        default)
            set_config_val $2 $3 ""
            # Pin assignments can conflict between services, so just restart
            # everything
            set_filthy
            ;;
        console)
            set_config_val $2 $3 "-1"
            # Restart everything
            set_filthy
            ;;
        0|1|2|3|4|5|6|7|8|9| \
        10|11|12|13|14|15|16| \
        17|18|19|20|21|22|23| \
        24|25|26|27)
            set_config_val $2 $3 $option
            # Restart everything
            set_filthy
            ;;
    esac
}

configure_pin_bias()
{
    VAL=`get_user_config_val $2 $3`
    DEFAULT=`get_sys_config_val $2 $3`

    dialog \
    --no-tags \
    --title "Configure $2 $1 Bias" \
    --radiolist "Select an option or \"Default\" to use the system default." 11 60 4 \
    default   "Default ($DEFAULT)" `on_off $VAL ""` \
    pull-up   "Pull-up"            `on_off $VAL pull-up` \
    pull-down "Pull-down"          `on_off $VAL pull-down` \
    disable   "Disable"            `on_off $VAL disable` 2>$ANSWER

    option=`cat $ANSWER`
    case "$option" in
        default)
            set_config_val $2 $3 ""
            set_dirty
            ;;
        pull-up|pull-down|disable)
            set_config_val $2 $3 $option
            set_dirty
            ;;
    esac
}

configure_pin_drive()
{
    VAL=`get_user_config_val $2 $3`
    DEFAULT=`get_sys_config_val $2 $3`

    dialog \
    --no-tags \
    --title "Configure $2 $1 Drive" \
    --radiolist "Select an option or \"Default\" to use the system default." 11 60 4 \
    default     "Default ($DEFAULT)" `on_off $VAL ""` \
    open-drain  "Open-drain"         `on_off $VAL open-drain` \
    open-source "Open-source"        `on_off $VAL open-source` \
    push-pull   "Push-pull"          `on_off $VAL push-pull` 2>$ANSWER

    option=`cat $ANSWER`
    case "$option" in
        default)
            set_config_val $2 $3 ""
            set_dirty
            ;;
        open-drain|open-source|push-pull)
            set_config_val $2 $3 $option
            set_dirty
            ;;
    esac
}

configure_pin_active_level()
{
    dialog_on_off_default "$2" "$3" "Configure $2 $1 Active Level" "Active High" "Active Low"
}

configure_ptt()
{
    while true
    do
        if is_initialized
        then
            dialog \
            --title "PTT Configuration" \
            --menu "Select a PTT option to configure." 15 60 4 \
            1 "Enable PTT" \
            2 "Configure Input GPIO Pin" \
            3 "Configure Input Pin Bias" \
            4 "Configure Input Pin Active State" \
            5 "Configure Output GPIO Pin" \
            6 "Configure Output Pin Bias" \
            7 "Configure Output Pin Drive" \
            8 "Configure Output Pin Active State" 2>$ANSWER

            option=`cat $ANSWER`
            case "$option" in
                1)
                    configure_ptt_enable
                    ;;
                2)
                    assign_pin Input PTT GPIONum 1
                    ;;
                3)
                    configure_pin_bias Input PTT Bias
                    ;;
                4)
                    configure_pin_active_level Input PTT ActiveLow
                    ;;
                5)
                    assign_pin Output PTT OutputGPIONum
                    ;;
                6)
                    configure_pin_bias Output PTT OutputBias
                    ;;
                7)
                    configure_pin_drive Output PTT OutputDrive
                    ;;
                8)
                    configure_pin_active_level Output PTT OutputActiveLow
                    ;;
                "")
                    return
                    ;;
            esac
        elif ! dialog --yesno "Config Not Initialized! Retry?" 0 0
        then
            return
        fi
    done
}

configure_volume_gpio()
{
    while true
    do
        if is_initialized
        then
            dialog \
            --title "Volume GPIO Configuration" \
            --menu "Select an option to configure." 11 60 4 \
            1 "Configure Up GPIO Pin" \
            2 "Configure Down GPIO Pin" \
            3 "Configure Pin Bias" \
            4 "Configure Pin Active State" 2>$ANSWER

            option=`cat $ANSWER`
            case "$option" in
                1)
                    assign_pin Up Volume UpGPIONum
                    ;;
                2)
                    assign_pin Down Volume DownGPIONum
                    ;;
                3)
                    configure_pin_bias Input Volume Bias
                    ;;
                4)
                    configure_pin_active_level Input Volume ActiveLow
                    ;;
                "")
                    return
                    ;;
            esac
        elif ! dialog --yesno "Config Not Initialized! Retry?" 0 0
        then
            return
        fi
    done
}

configure_selector_gpio()
{
    while true
    do
        if is_initialized
        then
            dialog \
            --title "Selector GPIO Configuration" \
            --menu "Select an option to configure." 12 60 4 \
            1 "Configure Primary Alert GPIO Pin" \
            2 "Configure Secondary Alert GPIO Pin" \
            3 "Configure Digital Transmit GPIO Pin" \
            4 "Configure Pin Bias" \
            5 "Configure Pin Active State" 2>$ANSWER

            option=`cat $ANSWER`
            case "$option" in
                1)
                    assign_pin "" Selector AGPIONum "" "Primary Alert"
                    ;;
                2)
                    assign_pin "" Selector BGPIONum "" "Secondary Alert"
                    ;;
                3)
                    assign_pin "" Selector DGPIONum "" "Digital Transmit"
                    ;;
                4)
                    configure_pin_bias Input Selector Bias
                    ;;
                5)
                    configure_pin_active_level Input Selector ActiveLow
                    ;;
                "")
                    return
                    ;;
            esac
        elif ! dialog --yesno "Config Not Initialized! Retry?" 0 0
        then
            return
        fi
    done
}

configure_hardware()
{
    while true
    do
        if is_initialized
        then
            dialog \
            --title "Hardware Configuration" \
            --menu "Select an option to configure." 11 60 4 \
            1 "Configure PTT GPIO" \
            2 "Configure Volume GPIO" \
            3 "Configure Selector GPIO" \
            4 "Assign Audio Devices" 2>$ANSWER

            option=`cat $ANSWER`
            case "$option" in
                1)
                    configure_ptt
                    ;;
                2)
                    configure_volume_gpio
                    ;;
                3)
                    configure_selector_gpio
                    ;;
                4)
                    assign_audio_devices
                    ;;
                "")
                    return
                    ;;
            esac
        elif ! dialog --yesno "Config Not Initialized! Retry?" 0 0
        then
            return
        fi
    done
}

enable_encryption()
{
    dialog_on_off_default Crypto Enabled "Configure Encryption"
}

configure_mode()
{
    while true
    do
        if is_initialized
        then
            VAL=`get_user_config_val Codec Mode`
            DEFAULT=`get_sys_config_val Codec Mode`

            dialog \
            --no-tags \
            --title "Configure Radio Mode" \
            --hfile "/usr/share/help/freedv.txt" \
            --radiolist "Select a mode or \"Default\" to use the system default. Press F1 for more information." 15 60 4 \
            default "Default ($DEFAULT)"    `on_off $VAL ""`    \
            700C    "700C  (HF/SSB)"        `on_off $VAL 700C`  \
            700D    "700D  (HF/SSB)"        `on_off $VAL 700D`  \
            700E    "700E  (HF/SSB)"        `on_off $VAL 700E`  \
            800XA   "800XA (Any)"           `on_off $VAL 800XA` \
            1600    "1600  (HF/SSB)"        `on_off $VAL 1600`  \
            2400B   "2400B (Narrowband FM)" `on_off $VAL 2400B` 2>$ANSWER

            option=`cat $ANSWER`
            case "$option" in
                default)
                    set_config_val Codec Mode ""
                    set_dirty
                    ;;
                700C|700D|700E|800XA|1600|2400B)
                    set_config_val Codec Mode $option
                    set_dirty
                    ;;
            esac

            return
        elif ! dialog --yesno "Config Not Initialized! Retry?" 0 0
        then
            return
        fi
    done
}

configure_squelch_thresh()
{
    VAL=`get_config_val Codec "SquelchThresh${1}"`

    while true
    do
        dialog \
        --title "Configure $1 SNR Threshold" \
        --inputbox "Enter a decimal number in decibels and press Enter." 8 60 "$VAL" 2>$ANSWER

        option=`cat $ANSWER`
        if test -z "$option"
        then
            return
        elif echo "$option" | grep -qxE '\-?([0-9]*\.)?[0-9]*'
        then
            set_config_val Codec "SquelchEnabled${1}" "$option"
            set_dirty
            return
        fi
    done
}

configure_rms_squelch_thresh()
{
    VAL_RAW=`get_config_val Audio "$2"`
    if test "$VAL_RAW" -le 0
    then
        VAL_RAW=1
    elif test "$VAL_RAW" -gt 32767
    then
        VAL_RAW=32767
    fi
    VAL=`echo "20 * l(${VAL_RAW}/32767)/l(10)" | bc -l | xargs printf %.1f`
    while true
    do
        dialog \
        --title "Configure RMS Noise Gate $1 Threshold" \
        --inputbox "Enter a decimal number in decibels and press Enter." 8 60 "$VAL" 2>$ANSWER

        option=`cat $ANSWER`
        if test -z "$option"
        then
            return
        elif echo "$option" | grep -qxE '\-?([0-9]*\.)?[0-9]*'
        then
            NEW_VAL=`echo "e(l(10)*(${option}/20)) * 32767" | bc -l | xargs printf %.0f`
            if test "$NEW_VAL" -gt 32767
            then
                NEW_VAL=32767
            fi
            set_config_val Audio "$2" "$NEW_VAL"
            set_dirty
            return
        fi
    done
}

configure_squelch_enable()
{
    dialog_on_off_default Codec SquelchEnabled "Enable Squelch"
}

configure_squelch()
{
    while true
    do
        if is_initialized
        then
            dialog \
            --title "Radio Squelch Configuration" \
            --hfile "/usr/share/help/squelch.txt" \
            --menu "Select a squelch option to configure. Press F1 for Help." 13 60 4 \
            1 "Enable SNR Squelch" \
            2 "Configure 700C SNR Threshold" \
            3 "Configure 700D SNR Threshold" \
            4 "Configure 700E SNR Threshold" \
            5 "Configure RMS Noise Gate Open Threshold" \
            6 "Configure RMS Noise Gate Close Threshold" 2>$ANSWER

            option=`cat $ANSWER`
            case "$option" in
                1)
                    configure_squelch_enable
                    ;;
                2)
                    configure_squelch_thresh 700C
                    ;;
                3)
                    configure_squelch_thresh 700D
                    ;;
                4)
                    configure_squelch_thresh 700E
                    ;;
                5)
                    configure_rms_squelch_thresh Open ModemSignalMinThresh
                    ;;
                6)
                    configure_rms_squelch_thresh Close ModemQuietMaxThresh
                    ;;
                "")
                    return
                    ;;
            esac
        elif ! dialog --yesno "Config Not Initialized! Retry?" 0 0
        then
            return
        fi
    done
}

broadcast_alert_dialog()
{
    while true
    do
        if is_initialized && is_tx_initialized
        then
            if dialog \
               --title "$1" \
               --inputbox "Type a message to broadcast and press Enter. Messages cannot exceed 160 characters." 8 60 "$2" 2>$ANSWER
            then
                LEN=`wc -c < "$ANSWER"`
                if test "$LEN" -eq 0
                then
                    return 0
                elif test "$LEN" -le 160
                then
                    return 0
                else
                    dialog --msgbox "Message too long!" 0 0
                fi
            else
                return 1
            fi
        elif ! dialog --yesno "System Not Initialized! Retry?" 0 0
        then
            return 1
        fi
    done
}

execute_alert()
{
    espeak_radio -w "$TTS_FILE" "$1" &> /dev/null && \
        /etc/init.d/S30jack_crypto_tx signal SIGUSR1
}

broadcast_custom_alert()
{
    broadcast_alert_dialog "Broadcast Custom Alert" && \
        test `wc -c < "$ANSWER"` -gt 0 && \
        espeak_radio -f "$ANSWER" -w "$TTS_FILE" &>/dev/null && \
        /etc/init.d/S30jack_crypto_tx signal SIGUSR1
}

broadcast_alert()
{
    PRIMARY=`get_config_val TTS Alert1`
    SECONDARY=`get_config_val TTS Alert2`

    if test -z "$PRIMARY" && test -z "$SECONDARY"
    then
        broadcast_custom_alert
    else
        rm -f /tmp/broadcast_alert

        if test -n "$PRIMARY"
        then
            echo "Primary \"'$PRIMARY'\" off" >> /tmp/broadcast_alert
        fi

        if test -n "$SECONDARY"
        then
            echo "Secondary \"'$SECONDARY'\" off" >> /tmp/broadcast_alert
        fi

        dialog \
        --title "Broadcast TTS Alert" \
        --radiolist "Select an Alert to broadcast." 10 60 4 \
        --file /tmp/broadcast_alert \
        Custom "" off 2>$ANSWER

        option=`cat $ANSWER`
        case "$option" in
            Primary)
                execute_alert "$PRIMARY"
                ;;
            Secondary)
                execute_alert "$SECONDARY"
                ;;
            Custom)
                broadcast_custom_alert
                ;;
        esac
    fi
}

configure_tts_alert()
{
    CUR=`get_config_val TTS "$2"`
    if broadcast_alert_dialog "Configure $1 Alert" "$CUR"
    then
        ALERT=`cat "$ANSWER"`
        set_config_val TTS "$2" "$ALERT"
    fi
}

configure_tts_alerts()
{
    while true
    do
        if is_initialized
        then
            dialog \
            --title "TTS Alert Broadcast Configuration" \
            --menu "Select an option to configure." 9 60 4 \
            1 "Configure Primary TTS Alert" \
            2 "Configure Secondary TTS Alert" 2>$ANSWER

            option=`cat $ANSWER`
            case "$option" in
                1)
                    configure_tts_alert Primary Alert1
                    ;;
                2)
                    configure_tts_alert Secondary Alert2
                    ;;
                "")
                    return
                    ;;
            esac
        elif ! dialog --yesno "Config Not Initialized! Retry?" 0 0
        then
            return
        fi
    done
}

assign_audio_device()
{
    VAL=`get_config_val JACK $2`

    dialog \
    --no-tags \
    --title "Assign $1 Audio Device" \
    --radiolist "When facing the USB ports, select the USB port to assign to the $1 audio device" 12 60 4\
    hw:USB_LL "Lower Left"  `on_off $VAL hw:USB_LL` \
    hw:USB_LR "Lower Right" `on_off $VAL hw:USB_LR` \
    hw:USB_UL "Upper Left"  `on_off $VAL hw:USB_UL` \
    hw:USB_UR "Upper Right" `on_off $VAL hw:USB_UR` 2>$ANSWER

    RET=$?

    option=`cat $ANSWER`
    case "$option" in
        hw:USB_LL | hw:USB_LR | hw:USB_UL | hw:USB_UR)
            set_config_val JACK $2 "$option"
            set_filthy
            ;;
        "")
            ;;
    esac

    return $RET
}

apply_settings()
{
    while true
    do
        if test ! -e "$DIRTY" && test ! -e "$FILTHY"
        then
            return
        elif is_initialized
        then
            if test -e "$FILTHY"
            then
                /etc/init.d/S32volume stop &> /dev/null
                /etc/init.d/S31jack_crypto_rx stop &> /dev/null
                /etc/init.d/S30jack_crypto_tx stop &> /dev/null
                /etc/init.d/S29jackd_rx stop &> /dev/null
                /etc/init.d/S28jackd_tx stop &> /dev/null

                while /etc/init.d/S28jackd_tx running || /etc/init.d/S29jackd_rx running || \
                      /etc/init.d/S30jack_crypto_tx running || /etc/init.d/S31jack_crypto_rx running ||
                      /etc/inti.d/S32volume running
                do
                    sleep .1
                done

                /etc/init.d/S28jackd_tx start &> /dev/null
                /etc/init.d/S29jackd_rx start &> /dev/null
                /etc/init.d/S30jack_crypto_tx start &> /dev/null
                /etc/init.d/S31jack_crypto_rx start &> /dev/null
                /etc/init.d/S32volume start &> /dev/null

                # Handling "Filthy" also takes care of "Dirty"
                rm -f "$DIRTY" "$FILTHY"
            elif test -e "$DIRTY"
            then
                /etc/init.d/S32volume stop &> /dev/null

                while /etc/init.d/S32volume running
                do
                    sleep .1
                done

                killall -SIGHUP jack_crypto_tx jack_crypto_rx
                /etc/init.d/S32volume start &> /dev/null
                rm -f "$DIRTY"
            fi

            return
        elif ! dialog --yesno "Config Not Initialized! Retry?" 0 0
        then
            return
        fi
    done
}

reload_asound_from_sd()
{
    if load_sd_sound_config
    then
        alsa_restore
    fi
}

assign_audio_devices()
{
    while true
    do
        if is_initialized
        then
            RESTART=1
            if assign_audio_device Headset VoiceDevice
            then
                RESTART=0
                assign_audio_device Radio ModemDevice
            fi

            if test $RESTART -eq 0
            then
                # The most common use case for assigning audio devices is to
                # go from everything unassigned to everything assigned. Since
                # at startup the scripts will "fix" the in-memory asound.state
                # by using the device number, reload it so that it can be updated
                # with the actual user port assignments
                # If the user re-assigns the audio devices after already having
                # done so, they will have to update the audio volume settings.
                reload_asound_from_sd
                apply_settings
            fi

            return
        elif ! dialog --yesno "Config Not Initialized! Retry?" 0 0
        then
            return
        fi
    done
}

load_from_sd()
{
    while true
    do
        if has_sd_card && is_initialized
        then
            RESULT=0
            for option in "$@"
            do
                case "$option" in
                    A)
                        if ! load_sd_sound_config
                        then
                            RESULT=1
                        else
                            alsa_restore
                        fi
                        ;;
                    R)
                        if ! load_sd_crypto_config
                        then
                            RESULT=1
                        else
                            set_filthy
                        fi
                        ;;
                    K)
                        if ! load_sd_key
                        then
                            RESULT=1
                        else
                            set_dirty
                        fi
                        ;;
                esac
            done

            apply_settings
            if test "$RESULT" -eq 0
            then
                dialog --msgbox "Settings Reloaded!" 0 0
            else
                dialog --msgbox "Settings Not Reloaded!" 0 0
            fi

            return
        elif ! dialog --yesno "Config Not Initialized or No SD Card! Retry?" 0 0
        then
            return
        fi
    done
}

save_to_sd()
{
    while true
    do
        if has_sd_card && is_initialized && ensure_sd_has_config_dir
        then
            RESULT=0
            for option in "$@"
            do
                case "$option" in
                    A)
                        if ! rm -f "$ASOUND_CFG" && alsactl store && save_sd_sound_config
                        then
                            RESULT=1
                        fi
                        ;;
                    R)
                        if ! save_sd_crypto_config
                        then
                            RESULT=1
                        fi
                        ;;
                    K)
                        if ! save_sd_key
                        then
                            RESULT=1
                        fi
                    esac
            done

            if test "$RESULT" -eq 0 && save_sd_seed
            then
                apply_settings
                dialog --msgbox "Settings Saved!" 0 0
            else
                dialog --msgbox "Settings Not Saved!" 0 0
            fi

            return
        elif ! dialog --yesno "Config Not Initialized or No SD Card! Retry?" 0 0
        then
            return
        fi
    done
}

duplicate_sd_card_loop()
{
    while dialog --yesno "Insert New SD Card and select Yes to copy or No to exit" 0 0
    do
        if partprobe && has_sd_card && copy_img_to_sd "$SD_IMG" 2>&1 | dialog --programbox "Writing SD Card" 20 60
        then
            true
        elif ! dialog --yesno "SD Card Write Failed! Retry?" 0 0
        then
            return
        fi
    done
}

duplicate_sd_card()
{
    while true
    do
        if has_sd_card && is_initialized
        then
            if copy_sd_to_img "$SD_IMG" 2>&1 | dialog --programbox "Reading SD Card" 20 60
            then
                duplicate_sd_card_loop
                rm -f "$SD_IMG"
                return
            elif ! dialog --yesno "SD Card Read Failed! Retry?" 0 0
            then
                rm -f "$SD_IMG"
                return
            else
                rm -f "$SD_IMG"
            fi
        elif ! dialog --yesno "Config Not Initialized or No SD Card! Retry?" 0 0
        then
            return
        fi
    done
}

advanced_sd_ops()
{
    selection="A R K"
    while true
    do
        if is_initialized
        then
            dialog \
            --title "Advanced SD Card Operations" \
            --menu "Select an operation to perform on the SD Card." 11 60 4 \
            1 "Select Configuration Items to Load/Save" \
            2 "Save Selected Items To SD Card" \
            3 "Load Selected Items From SD Card" \
            4 "Duplicate This SD Card" 2>$ANSWER

            option=`cat $ANSWER`
            case "$option" in
                1)
                    if dialog \
                       --no-tags \
                       --title "SD Card Items" \
                       --checklist "Select the Settings to Load/Save, then press OK" 10 60 3 \
                       A "Audio Settings" `on_off_checklist "$selection" "A"` \
                       R "Radio Settings" `on_off_checklist "$selection" "R"` \
                       K "Encryption Key" `on_off_checklist "$selection" "K"` 2>$ANSWER
                    then
                        selection=`cat $ANSWER`
                    fi
                    ;;
                2)
                    save_to_sd $selection
                    ;;
                3)
                    load_from_sd $selection
                    ;;
                4)
                    duplicate_sd_card
                    ;;
                "")
                    return
                    ;;
            esac
        elif ! dialog --yesno "Config Not Initialized! Retry?" 0 0
        then
            return
        fi
    done
}

show_boot_messages()
{
    dialog \
    --title "Boot Messagaes" \
    --textbox /var/log/messages 0 0
}

show_user_settings()
{
    while true
    do
        if is_initialized
        then
            dialog \
            --title "Current Settings" \
            --textbox "$CRYPTO_INI_USR" 30 80

            return
        elif ! dialog --yesno "Config Not Initialized! Retry?" 0 0
        then
            return
        fi
    done
}

start_alsamixer()
{
    DEV=`get_config_val JACK "$1"`
    while true
    do
        if sound_dev_active "$DEV"
        then
            alsamixer -D "$DEV" -V all
            return
        elif ! dialog --yesno "$2 Device $DEV Not Ready! Retry?" 0 0
        then
            return
        fi
    done
}

key_slot_str()
{
    has_key "$1" && echo "*Slot $1" || echo " Slot $1"
}

# $1: 1 to show all or 0 to show only entries with keys
# $2: Title Text
# $3: On Key Slot (optional)
# $4: 1 to display checklist (optional)
show_key_slot_dialog()
{
    rm -f /tmp/key_slots_dialog &>/dev/null
    touch /tmp/key_slots_dialog &>/dev/null
    IDX=1
    while test "$IDX" -le 256
    do
        if test "$1" -eq 1 || has_key "$IDX"
        then
            echo "$IDX \"`key_slot_str $IDX`\" `on_off "$IDX" "$3"`" >> /tmp/key_slots_dialog
        fi
        IDX=$((IDX+1))
    done

    if test "$4" = "1"
    then
        DIALOG_TYPE="checklist"
    else
        DIALOG_TYPE="radiolist"
    fi

    if test -n "$3"
    then
        DEFAULT_ARG="--default-item $3"
    fi

    dialog \
    --title "Select Key Slot(s) to $2" \
    --no-tags \
    $DEFAULT_ARG \
    --"$DIALOG_TYPE" "Slots with an asterisk (*) in front of the name have a key" 24 60 4 \
    --file /tmp/key_slots_dialog
}

generate_encryption_keys()
{
    while true
    do
        if is_initialized
        then
            if show_key_slot_dialog 1 "Hold the New Keys" "" 1 2>$ANSWER
            then
                RESULT=0
                for IDX in `cat $ANSWER`
                do
                    if gen_key "$IDX"
                    then
                        set_dirty
                    else
                        RESULT=1
                    fi
                done

                if test $RESULT -eq 0
                then
                    dialog --msgbox "New Keys Created!" 0 0
                else
                    dialog --msgbox "New Keys Not Created!" 0 0
                fi
            fi

            return
        elif ! dialog --yesno "Config Not Initialized! Retry?" 0 0
        then
            return
        fi
    done
}

delete_encryption_keys()
{
    while true
    do
        if is_initialized
        then
            if show_key_slot_dialog 0 "Delete" "" 1 2>$ANSWER
            then
                RESULT=0
                for IDX in `cat $ANSWER`
                do
                    if rm "`get_key_path $IDX`"
                    then
                        set_dirty
                    else
                        RESULT=1
                    fi
                done

                if test $RESULT -eq 0
                then
                    dialog --msgbox "Keys Deleted!" 0 0
                else
                    dialog --msgbox "Keys Not Deleted!" 0 0
                fi
            fi

            return
        elif ! dialog --yesno "Config Not Initialized! Retry?" 0 0
        then
            return
        fi
    done
}

select_active_key()
{
    while true
    do
        if is_initialized
        then
            CUR_IDX=`get_config_val Crypto KeyIndex`

            show_key_slot_dialog 0 "Set As Active" "$CUR_IDX" 2>$ANSWER
            NEW_IDX=`cat $ANSWER`
            if test -n "$NEW_IDX" && set_config_val Crypto KeyIndex "$NEW_IDX"
            then
                set_dirty
                return 0
            else
                return 1
            fi
        elif ! dialog --yesno "Config Not Initialized! Retry?" 0 0
        then
            return 1
        fi
    done
}

configure_encryption()
{
    while true
    do
        if is_initialized
        then
            dialog \
            --title "Encryption Configuration" \
            --menu "Select an option to configure." 10 60 4 \
            1 "Enable Encryption" \
            2 "Generate Encryption Keys" \
            3 "Delete Encryption Keys" 2>$ANSWER

            option=`cat $ANSWER`
            case "$option" in
                1)
                    enable_encryption
                    ;;
                2)
                    generate_encryption_keys
                    ;;
                3)
                    delete_encryption_keys
                    ;;
                "")
                    return
                    ;;
            esac
        elif ! dialog --yesno "Config Not Initialized! Retry?" 0 0
        then
            return
        fi
    done
}

configure_config_util()
{
    while true
    do
        if is_initialized
        then
            VAL=`get_user_config_val Config Enabled`
            DEFAULT=`get_sys_config_val Config Enabled`

            if test "$DEFAULT" = "0"
            then
                DEFAULT=Disabled
            else
                DEFAULT=Enabled
            fi

            dialog \
            --no-tags \
            --title "Disable Console Interface?" \
            --radiolist "If Enabled, the Console Interface will be shown at startup. If Disabled, the display will be locked at startup. If Disabled and saved to the SD Card, it cannot be re-enabled once the system is turned off" 13 60 3 \
            default "Default ($DEFAULT)" `on_off $VAL ""` \
            1       "Enabled"            `on_off $VAL 1`  \
            0       "Disabled"           `on_off $VAL 0` 2>$ANSWER

            option=`cat $ANSWER`
            case "$option" in
                default)
                    set_config_val Config Enabled ""
                    # Don't need to set Dirty since services unaffected
                    ;;
                0|1)
                    set_config_val Config Enabled $option
                    # Don't need to set Dirty since services unaffected
                    ;;
            esac

            return
        elif ! dialog --yesno "Config Not Initialized! Retry?" 0 0
        then
            return
        fi
    done
}

configuration_menu()
{
    while true
    do
        if dialog \
           --title "Configuration Options" \
           --hfile "/usr/share/help/config.txt" \
           --menu "Select an option. Press F1 for Help." 18 60 4 \
           1 "Configure Radio Mode" \
           2 "Configure Radio Squelch" \
           3 "Configure Encryption" \
           4 "Configure TTS Alert Broadcasts" \
           5 "Configure Hardware" \
           6 "Disable Console Interface" \
           V "View Current Settings" \
           A "Apply Current Settings" \
           R "Reload Settings From SD Card" \
           S "Save Current Settings To SD Card" \
           C "Advanced SD Card Operations" 2>$ANSWER
        then
            option=`cat $ANSWER`
            case "$option" in
                1)
                    configure_mode
                    ;;
                2)
                    configure_squelch
                    ;;
                3)
                    configure_encryption
                    ;;
                4)
                    configure_tts_alerts
                    ;;
                5)
                    configure_hardware
                    ;;
                6)
                    configure_config_util
                    ;;
                V)
                    show_user_settings
                    ;;
                A)
                    apply_settings
                    ;;
                R)
                    load_from_sd A R K
                    ;;
                S)
                    save_to_sd A R K
                    ;;
                C)
                    advanced_sd_ops
                    ;;
                *)
                    return
                    ;;
            esac
        else
            return
        fi
    done
}

transmit_voice()
{
    while true
    do
        if is_initialized && is_tx_initialized
        then
            if /etc/init.d/S30jack_crypto_tx signal SIGRTMIN
            then
                dialog \
                --title "Voice Transmission" \
                --msgbox "Now Transmitting. Press OK to Stop." 5 39
                /etc/init.d/S30jack_crypto_tx signal SIGRTMIN
            fi

            return
        elif ! dialog --yesno "System Not Initialized! Retry?" 0 0
        then
            return
        fi
    done
}

select_digital()
{
    while true
    do
        if is_initialized
        then
            VAL=`get_config_val Codec Enabled`

            dialog \
            --no-tags \
            --title "Select Digital or Analog Transmission" \
            --radiolist "If using Analog, all transmissions will be sent in the clear." 10 60 3 \
            1       "Digital" `on_off $VAL 1`  \
            0       "Analog"  `on_off $VAL 0` 2>$ANSWER

            option=`cat $ANSWER`
            case "$option" in
                0|1)
                    set_config_val Codec Enabled $option
                    set_dirty
                    ;;
            esac

            return 0
        elif ! dialog --yesno "Config Not Initialized! Retry?" 0 0
        then
            return 1
        fi
    done
}

main_menu()
{
    while true
    do
        rm -f /tmp/transmit_opt
        touch /tmp/transmit_opt

        PTT_ENABLED=`get_config_val PTT Enabled`
        PTT_GPIONUM=`get_config_val PTT GPIONum`

        HEIGHT=15
        if test "$PTT_ENABLED" -ne 0 && test "$PTT_GPIONUM" -eq "-1"
        then
            echo "T \"Transmit Voice\"" > /tmp/transmit_opt
            HEIGHT=$((HEIGHT+1))
        fi

        if dialog \
           --cancel-label "LOCK" \
           --title "Crypto Voice Module Console Interface" \
           --menu "Select an option." $HEIGHT 60 4 \
           --file /tmp/transmit_opt \
           A "Broadcast TTS Alert" \
           H "Adjust Headset Volume" \
           R "Adjust Radio Volume" \
           K "Select Active Key" \
           D "Select Digital/Analog" \
           M "View Boot Messages" \
           O "Configuration Options" \
           L "Shell Access (Experts Only)" 2>$ANSWER
        then
            option=`cat $ANSWER`
            case "$option" in
                T)
                    transmit_voice
                    ;;
                A)
                    broadcast_alert
                    ;;
                H)
                    start_alsamixer VoiceDevice Headset
                    ;;
                R)
                    start_alsamixer ModemDevice Radio
                    ;;
                K)
                    # Auto apply settings in the Main Menu
                    select_active_key && apply_settings
                    ;;
                D)
                    select_digital && apply_settings
                    ;;
                L)
                    clear && exec /sbin/getty -L `tty` 115200
                    ;;
                M)
                    show_boot_messages
                    ;;
                O)
                    configuration_menu
                    apply_settings
                    ;;
            esac
        else
            disable_config
            exit 0
        fi
    done
}

dmesg -n 1

# ForceShowConfig setting must be turned on in the firmware itself
if (test `get_sys_config_val Diagnostics ForceShowConfig` -ne 0) ||
   (wait_initialized && test `get_config_val Config Enabled` -ne 0)
then
    main_menu
else
    exec dialog --msgbox "Display Locked" 0 0
fi

#!/usr/bin/env sh

. /etc/profile.d/shell_functions.sh

exec 2>/dev/null

ANSWER=/tmp/answer
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
                *)
                    return 1
                    ;;
            esac

            return 0
        elif ! dialog --yesno "Config Not Initialized! Retry?" 0 0
        then
            return 1
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
assign_pin()
{
    VAL=`get_user_config_val "$2" "$3"`
    DEFAULT=`get_sys_config_val "$2" "$3"`

    HEIGHT=37
    CONSOLE_ARGS=`mktemp`
    if test "$4" -eq 1
    then
        echo "console \"Console Interface\" `on_off $VAL "-1"`" >> "$CONSOLE_ARGS"
        HEIGHT=$((HEIGHT+1))
    fi

    dialog \
    --no-tags \
    --title "Configure $2 $1 Pin" \
    --radiolist "Select an option or \"Default\" to use the system default. Refer to https://pinout.xyz for more information." "$HEIGHT" 60 4 \
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

    rm -f "$CONSOLE_ARGS"

    option=`cat $ANSWER`
    case "$option" in
        default)
            set_config_val "$2" "$3" ""
            # Pin assignments can conflict between services, so just restart
            # everything
            set_filthy
            ;;
        console)
            set_config_val "$2" "$3" "-1"
            # Restart everything
            set_filthy
            ;;
        0|1|2|3|4|5|6|7|8|9| \
        10|11|12|13|14|15|16| \
        17|18|19|20|21|22|23| \
        24|25|26|27)
            set_config_val "$2" "$3" $option
            # Restart everything
            set_filthy
            ;;
    esac
}

configure_pin_bias()
{
    VAL=`get_user_config_val "$2" "$3"`
    DEFAULT=`get_sys_config_val "$2" "$3"`

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
            set_config_val "$2" "$3" ""
            # Set filthy on all pin config changes just to be safe
            set_filthy
            ;;
        pull-up|pull-down|disable)
            set_config_val "$2" "$3" "$option"
            # Set filthy on all pin config changes just to be safe
            set_filthy
            ;;
    esac
}

configure_pin_drive()
{
    VAL=`get_user_config_val "$2" "$3"`
    DEFAULT=`get_sys_config_val "$2" "$3"`

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
            set_config_val "$2" "$3" ""
            # Set filthy on all pin config changes just to be safe
            set_filthy
            ;;
        open-drain|open-source|push-pull)
            set_config_val "$2" "$3" "$option"
            # Set filthy on all pin config changes just to be safe
            set_filthy
            ;;
    esac
}

configure_pin_active_level()
{
    dialog_on_off_default "$2" "$3" "Configure $2 $1 Active Level" "Active High" "Active Low" && \
        set_filthy
}

configure_pin_debounce()
{
    VAL=`get_config_val "$2" "$3"`
    DEFAULT=`get_sys_config_val "$2" "$3"`

    dialog \
    --title "Configure $2 $1 Debounce" \
    --rangebox "Use the +/- buttons to adjust. Higher numbers reduce glitches but require heavier button presses." 9 60 5 20 "$VAL" 2>$ANSWER

    option=`cat $ANSWER`
    if test -n "$option"
    then
        set_config_val "$2" "$3" "$option"
        set_filthy
    fi
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

configure_keypad_gpio()
{
    while true
    do
        if is_initialized
        then
            dialog \
            --title "Selector GPIO Configuration" \
            --menu "Select an option to configure." 15 60 4 \
            1 "Configure Volume Up GPIO Pin" \
            2 "Configure Volume Down GPIO Pin" \
            3 "Configure Primary Alert GPIO Pin" \
            4 "Configure Secondary Alert GPIO Pin" \
            5 "Configure Digital/Analog Toggle GPIO Pin" \
            6 "Configure Pin Bias" \
            7 "Configure Pin Active State" \
            8 "Configure Pin Debounce" 2>$ANSWER

            option=`cat $ANSWER`
            case "$option" in
                1)
                    assign_pin "Volume Up" Keypad UpGPIONum
                    ;;
                2)
                    assign_pin "Volume Down" Keypad DownGPIONum
                    ;;
                3)
                    assign_pin "Primary Alert" Keypad AGPIONum
                    ;;
                4)
                    assign_pin "Secondary Alert" Keypad BGPIONum
                    ;;
                5)
                    assign_pin "Digital/Analog Toggle" Keypad DGPIONum
                    ;;
                6)
                    configure_pin_bias Input Keypad Bias
                    ;;
                7)
                    configure_pin_active_level Input Keypad ActiveLow
                    ;;
                8)
                    configure_pin_debounce Input Keypad Debounce
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
            --menu "Select an option to configure." 10 60 4 \
            1 "Configure PTT GPIO" \
            2 "Configure Keypad GPIO" \
            3 "Assign Audio Devices" 2>$ANSWER

            option=`cat $ANSWER`
            case "$option" in
                1)
                    configure_ptt
                    ;;
                2)
                    configure_keypad_gpio
                    ;;
                3)
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
                    set_config_val Codec Mode "$option"
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

broadcast_custom_alert()
{
    broadcast_alert_dialog "Broadcast Custom Alert" && \
        test `wc -c < "$ANSWER"` -gt 0 && \
        execute_alert_broadcast -f "$ANSWER"
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
                execute_alert_broadcast "$PRIMARY"
                ;;
            Secondary)
                execute_alert_broadcast "$SECONDARY"
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
    VAL=`get_config_val JACK "$2"`

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
            set_config_val JACK "$2" "$option"
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
                /etc/init.d/S32keypad_control stop &> /dev/null
                /etc/init.d/S31jack_crypto_rx stop &> /dev/null
                /etc/init.d/S30jack_crypto_tx stop &> /dev/null
                /etc/init.d/S29jackd_rx stop &> /dev/null
                /etc/init.d/S28jackd_tx stop &> /dev/null

                while /etc/init.d/S28jackd_tx running || /etc/init.d/S29jackd_rx running || \
                      /etc/init.d/S30jack_crypto_tx running || /etc/init.d/S31jack_crypto_rx running ||
                      /etc/init.d/S32keypad_control running
                do
                    sleep .1
                done

                /etc/init.d/S28jackd_tx start &> /dev/null
                /etc/init.d/S29jackd_rx start &> /dev/null
                /etc/init.d/S30jack_crypto_tx start &> /dev/null
                /etc/init.d/S31jack_crypto_rx start &> /dev/null
                /etc/init.d/S32keypad_control start &> /dev/null

                # Handling "Filthy" also takes care of "Dirty"
                rm -f "$DIRTY" "$FILTHY"
            elif test -e "$DIRTY"
            then
                killall -SIGHUP jack_crypto_tx jack_crypto_rx
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
                    E)
                        if ! load_sd_dkek
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
                        if ! (rm -f "$ASOUND_CFG" && alsactl store && save_sd_sound_config)
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
                    E)
                        if ! save_sd_dkek
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

# sdtool uses the same return code for a command timeout as
# for a permlocked drive. So have to do a lock/permlock
# then a status
#
# $1: Device (eg. /dev/mmcblk0)
# $2: Commend (eg. lock/permlock)
sdtool_with_status()
{
    sdtool "$1" "$2" &> /dev/null
    sdtool "$1" status &> /dev/null
}

try_ensure_is_writable()
{
    if test "$1" = "/dev/sda"
    then
        return 0
    else
        sdtool_with_status "$1" unlock &> /dev/null
        SD_STAT="$?"
        case "$SD_STAT" in
            255)
                dialog --msgbox "SD Card is permanent write-protected" 0 0
                ;;
            254)
                dialog --msgbox "SD Card is temporary write-protected but could not be unlocked" 0 0
                ;;
        esac

        test "$SD_STAT" -eq 253
    fi
}

# Make sure a file named BAD_WP doesn't already exist on the card
# Try to create it
# Make sure the file isn't created
test_write_protect()
{
    ! mdir_sd ::/BAD_WP && \
        mcopy_text_sd /var/run/initialized ::/BAD_WP && \
        ! mdir_sd ::/BAD_WP
}

# $1 Card image
# $2 Partition image
# $3 Add seed to partition
# $4 lock the SD Card
# $5 Serialize the SD Card
duplicate_sd_card_loop()
{
    if test -z "$4"
    then
        DEV_PROMPT="SD Card or USB Drive"
    else
        DEV_PROMPT="SD Card"
    fi

    while dialog --yesno "Insert $DEV_PROMPT and select Yes to copy or No to exit" 0 0
    do
        if test "$3" -ne 0
        then
            dd if=/dev/random of="$SEED_FILE" bs=512 count=1 && mcopy_bin -i "$2" "$SEED_FILE" ::seed
        fi

        if test "$5" -ne 0
        then
            DEVICE_SERIAL_NUMBER=`uuidd -r`
            DEVICE_DECRYPTION_KEYFILE=`mktemp`
            DEVICE_ENCRYPTION_KEYFILE=`mktemp`
            dialog --infobox "Generating Device Key. This may take a while..." 0 0
            openssl genrsa -out "$DEVICE_DECRYPTION_KEYFILE" 4096
            openssl rsa -in "$DEVICE_DECRYPTION_KEYFILE" -pubout -out "$DEVICE_ENCRYPTION_KEYFILE"

            SERIAL_PART_IMG=`mktemp`
            cp "$2" "$SERIAL_PART_IMG"
            mcopy_bin -i "$SERIAL_PART_IMG" "$DEVICE_DECRYPTION_KEYFILE" ::config/"${DEVICE_SERIAL_NUMBER}.kdk"

            combine_img_p1 "$1" "$SERIAL_PART_IMG"
            rm -f "$SERIAL_PART_IMG" "$DEVICE_DECRYPTION_KEYFILE"
        else
            combine_img_p1 "$1" "$2"
        fi

        # Only write keys to USB drives
        if test -z "$4" && has_usb_drive
        then
            DST_DRIVE="/dev/sda"
            DST_NAME="USB Drive"
        else
            DST_DRIVE="/dev/mmcblk0"
            DST_NAME="SD Card"
        fi

        if partprobe && test -b "$DST_DRIVE" && try_ensure_is_writable "$DST_DRIVE" && copy_img_to_sd "$1" "$DST_DRIVE" 2>&1 | dialog --programbox "Writing $DST_NAME" 20 60
        then
            if test -n "$DEVICE_ENCRYPTION_KEYFILE"
            then
                mv "$DEVICE_ENCRYPTION_KEYFILE" "${DKEK_DIR}/${DEVICE_SERIAL_NUMBER}.kek"
            fi

            if test "$4" -ne 0
            then
                case "`get_sys_config_val Config ProtectMode`" in
                    lock)
                        LOCK_CMD="lock"
                        LOCK_CODE=254
                        ;;
                    permlock)
                        LOCK_CMD="permlock"
                        LOCK_CODE=255
                        ;;
                    *)
                        LOCK_CMD="unlock"
                        LOCK_CODE=253
                        ;;
                esac
                sdtool_with_status "$DST_DRIVE" "$LOCK_CMD"
                if test "$?" -ne "$LOCK_CODE"
                then
                    # If we didn't get the correct status code back,
                    # the write protect failed
                    MSG="Could Not Write Protect!"
                    if test -n "$DEVICE_SERIAL_NUMBER"
                    then
                        MSG="${MSG}\nDevice Serial Number: $DEVICE_SERIAL_NUMBER"
                    fi

                    dialog --msgbox "$MSG" 0 0
                elif test "$LOCK_CODE" -ne 253 && ! test_write_protect
                then
                    # If we're doing a lock or permlock but are still able
                    # to write files to the device after, then write protect
                    # isn't actually "protecting" anything
                    MSG="Write Protect Doesnt Work!"
                    if test -n "$DEVICE_SERIAL_NUMBER"
                    then
                        MSG="${MSG}\nDevice Serial Number: $DEVICE_SERIAL_NUMBER"
                    fi

                    dialog --msgbox "$MSG" 0 0
                else
                    # Otherwise write protect appears to have succeeded
                    # and appears to work
                    MSG="Write Protect Succeeded!"
                    if test -n "$DEVICE_SERIAL_NUMBER"
                    then
                        MSG="${MSG}\nDevice Serial Number: $DEVICE_SERIAL_NUMBER"
                    fi

                    dialog --msgbox "$MSG" 0 0
                fi
            fi
        elif ! dialog --yesno "$DST_NAME Write Failed! Retry?" 0 0
        then
            if test -n "$DEVICE_DECRYPTION_KEYFILE"
            then
                rm "$DEVICE_ENCRYPTION_KEYFILE"
            fi

            return 1
        elif test -n "$DEVICE_ENCRYPTION_KEYFILE"
        then
            rm "$DEVICE_ENCRYPTION_KEYFILE"
        fi
    done
}

# $1 1 to include red keys, 0 to exclude
# $2 1 to Enable Console Interface, 0 to Disable
# $3 1 for Key Fill Device, 0 for Radio
# $4 1 to Serialize the Device
write_device_image()
{
    while true
    do
        if is_initialized
        then
            TMP_CRYPTO_INI=`mktemp`
            cp "$CRYPTO_INI_USR" "$TMP_CRYPTO_INI"

            iniset Config ConfigPassword '*' "$TMP_CRYPTO_INI"
            if test "$2" -ne 0
            then
                iniset Config Enabled 1 "$TMP_CRYPTO_INI"
            else
                iniset Config Enabled 0 "$TMP_CRYPTO_INI"
            fi

            if test "$3" -ne 0
            then
                iniset Config KeyFillOnly 1 "$TMP_CRYPTO_INI"
            else
                iniset Config KeyFillOnly 0 "$TMP_CRYPTO_INI"
            fi

            rm -f "$ASOUND_CFG" && alsactl store

            TMP_DOS_IMG=`mktemp`
            TMP_SD_IMG=`mktemp`
            cp "$SD_IMG_DOS" "$TMP_DOS_IMG"
            cp "$SD_IMG" "$TMP_SD_IMG"

            mdeltree -i "$TMP_DOS_IMG" ::config ::black_keys
            if ensure_sd_has_config_dir "$TMP_DOS_IMG" && \
               mcopy_text -i "$TMP_DOS_IMG" "$ASOUND_CFG" ::config/asound.state && \
               mcopy_text -i "$TMP_DOS_IMG" "$TMP_CRYPTO_INI" ::config/crypto.ini
            then
                if test "$1" -ne 0
                then
                    mcopy_bin -i "$TMP_DOS_IMG" /etc/keys/key* ::config/
                fi

                duplicate_sd_card_loop "$TMP_SD_IMG" "$TMP_DOS_IMG" 1 1 $4
                rm -f "$TMP_SD_IMG" "$TMP_DOS_IMG" "$TMP_CRYPTO_INI"
                return
            elif ! dialog --yesno "SD Card Write Failed! Retry?" 0 0
            then
                rm -f "$TMP_SD_IMG" "$TMP_DOS_IMG" "$TMP_CRYPTO_INI"
                return
            else
                rm -f "$TMP_SD_IMG" "$TMP_DOS_IMG" "$TMP_CRYPTO_INI"
            fi
        elif ! dialog --yesno "Config Not Initialized or No SD Card! Retry?" 0 0
        then
            return
        fi
    done
}

# $1: 0 to write red keys, 1 to write black keys, 2 to write key encryption keys
write_key_image()
{
    while true
    do
        if is_initialized && has_any_red_keys
        then
            TMP_DOS_IMG=`mktemp`
            TMP_SD_IMG=`mktemp`

            if dd if=/dev/zero of="$TMP_DOS_IMG" bs=512 count=16002 && \
               mkdosfs "$TMP_DOS_IMG" &> /dev/null
            then
                case "$1" in
                    0)
                        ensure_sd_has_config_dir "$TMP_DOS_IMG"
                        mcopy_bin -i "$TMP_DOS_IMG" /etc/keys/key* ::config/
                        ;;
                    1)
                        ensure_sd_has_black_keys_dir "$TMP_DOS_IMG"
                        mcopy_bin -i "$TMP_DOS_IMG" "$BLACK_KEY_DIR"/*.key* ::black_keys/
                        ;;
                    2)
                        ensure_sd_has_config_dir "$TMP_DOS_IMG"
                        mcopy_bin -i "$TMP_DOS_IMG" "$DKEK_DIR"/*.kek ::config/
                        ;;
                esac

                dd if=/dev/zero of="$TMP_SD_IMG" bs=512 count=16065
                echo -e "n\np\n1\n63\n16064\nt\nc\na\n1\nw\n" | fdisk "$TMP_SD_IMG" &> /dev/null

                duplicate_sd_card_loop "$TMP_SD_IMG" "$TMP_DOS_IMG"
                rm -f "$TMP_DOS_IMG" "$TMP_SD_IMG"
                return
            elif ! dialog --yesno "SD Card Write Failed! Retry?" 0 0
            then
                rm -f "$TMP_SD_IMG" "$TMP_DOS_IMG"
                return
            else
                rm -f "$TMP_SD_IMG" "$TMP_DOS_IMG"
            fi
        elif ! dialog --yesno "Config Not Initialized or No SD Card! Retry?" 0 0
        then
            return
        fi
    done
}

write_image()
{
    while true
    do
        if is_initialized
        then
            rm -f /tmp/red_key_opts
            rm -f /tmp/black_key_opts
            rm -f /tmp/dkek_opts
            touch /tmp/red_key_opts
            touch /tmp/black_key_opts
            touch /tmp/dkek_opts

            HEIGHT=12

            if has_any_dkeks
            then
                echo "4 \"Key Encryption Keys Only\"" >> /tmp/dkek_opts
                HEIGHT=$((HEIGHT+1))
            fi

            if has_any_black_keys
            then
                echo "5 \"Black Keys Only\"" >> /tmp/black_key_opts
                HEIGHT=$((HEIGHT+1))
            fi

            if has_any_red_keys
            then
                echo "6 \"Red Keys Only\"" >> /tmp/red_key_opts
                echo "7 \"Locked Handheld, With Red Keys (OBSOLETE)\"" >> /tmp/red_key_opts
                echo "8 \"Locked Base Station, With Red Keys (OBSOLETE)\"" >> /tmp/red_key_opts
                HEIGHT=$((HEIGHT+3))
            fi

            dialog \
            --title "Deployment Options" \
            --menu "Select a type of image to deploy. Deploying a Locked Device Image to an SD Card will permanently make it read-only." "$HEIGHT" 60 4 \
            1 "Locked Key Gen/Fill Device" \
            2 "Locked Handheld, No Keys" \
            3 "Locked Base Station, No Keys" \
            --file /tmp/dkek_opts \
            --file /tmp/black_key_opts \
            --file /tmp/red_key_opts 2>$ANSWER

            option=`cat $ANSWER`
            case "$option" in
                1)
                    write_device_image 0 1 1
                    ;;
                2)
                    write_device_image 0 0 0 1
                    ;;
                3)
                    write_device_image 0 1 0 1
                    ;;
                4)
                    write_key_image 2
                    ;;
                5)
                    write_key_image 1
                    ;;
                6)
                    write_key_image 0
                    ;;
                7)
                    write_device_image 1 0 0 1
                    ;;
                8)
                    write_device_image 1 1 0 1
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

start_alsamixer()
{
    DEV=`get_config_val JACK "$1"`
    while true
    do
        if sound_dev_active "$DEV"
        then
            XDG_CONFIG_HOME=/etc alsamixer -D "$DEV" -V all
            return
        elif ! dialog --yesno "$2 Device $DEV Not Ready! Retry?" 0 0
        then
            return
        fi
    done
}

key_slot_str()
{
    if has_red_key "$1"
    then
        echo "*Slot $1 (Red)"
    elif has_black_key "$1"
    then
        echo "*Slot $1 (Black)"
    else
        echo " Slot $1"
    fi
}

# $1: 1 to show all, 0 to show only entries with red or black keys,
#     2 to show only entries with red keys
# $2: Title Text
# $3: On Key Slot (optional)
# $4: 1 to display checklist (optional)
show_key_slot_dialog()
{
    rm -f /tmp/key_slots_dialog &>/dev/null
    touch /tmp/key_slots_dialog &>/dev/null
    COUNT=0
    IDX=1
    while test "$IDX" -le 256
    do
        if test "$1" -eq 1 || has_red_key "$IDX" || (test "$1" -eq 0 && has_black_key "$IDX")
        then
            COUNT=$((COUNT+1))
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

    if test "$COUNT" -eq 0
    then
        dialog --msgbox "No Keys Loaded!" 0 0
        return 1
    else
        dialog \
        --title "Select Key Slot(s) to $2" \
        --no-tags \
        $DEFAULT_ARG \
        --"$DIALOG_TYPE" "Slots with an asterisk (*) in front of the name have a key" 24 60 4 \
        --file /tmp/key_slots_dialog
    fi
}

generate_encryption_keys()
{
    while true
    do
        if is_initialized
        then
            if show_key_slot_dialog 1 "Hold the New Keys" "" 1 2>$ANSWER
            then
                has_any_red_keys
                HAD_KEYS="$?"

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
                    if test "$HAD_KEYS" -ne 0 && has_any_red_keys
                    then
                        set_key_index "`next_key_idx 256`"
                        set_dirty
                    fi
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
                    if get_all_key_paths "$IDX" | xargs rm -f
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
            CUR_IDX=`get_key_index`

            show_key_slot_dialog 2 "Set As Active" "$CUR_IDX" 2>$ANSWER
            NEW_IDX=`cat $ANSWER`
            if test -n "$NEW_IDX" && set_key_index "$NEW_IDX"
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
            2 "Create Encryption Keys" \
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

configure_password()
{
    if password_prompt
    then
        PASSWD_FILE=`mktemp`
        PASSWD_FILE2=`mktemp`
        while true
        do
            if dialog \
               --title "Configuration Menu Password" \
               --passwordbox "Enter New Configuration Menu Password. Leave Blank to Disable Password Protection" 8 60 2>"$PASSWD_FILE" && \
               dialog \
               --title "Verify Password" \
               --passwordbox "Re-enter New Configuration Menu Password" 8 60 2> "$PASSWD_FILE2"
            then
                PASSWD1=`cat "$PASSWD_FILE"`
                PASSWD2=`cat "$PASSWD_FILE2"`
                if test "$PASSWD1" = "$PASSWD2"
                then
                    if test -z "$PASSWD1"
                    then
                        DLG_PASSWD=""
                        MSGBOX_ACTION="Cleared"
                    else
                        DLG_PASSWD=`mkpasswd -P 0 -m sha512 < "$PASSWD_FILE"`
                        MSGBOX_ACTION="Set"
                    fi

                    set_config_val Config ConfigPassword "$DLG_PASSWD"
                    rm -f "$PASSWD_FILE" "$PASSWD_FILE2"
                    dialog --msgbox "Password ${MSGBOX_ACTION}!" 0 0
                    return 0
                else
                    dialog --msgbox "Passwords Do Not Match!" 0 0
                fi
            else
                rm -f "$PASSWD_FILE" "$PASSWD_FILE2"
                return 1
            fi
        done
    else
        return 1
    fi
}

run_key_fill()
{
    ifconfig eth0 up
    /etc/init.d/manual/S10pppoe_server start &> /dev/null
    /etc/init.d/manual/S50sshd start &> /dev/null
    /etc/init.d/manual/S60keyfill_led start &> /dev/null

    dialog \
    --title "Ethernet Key Fill" \
    --msgbox "Key Fill Active. Press OK To Stop" 5 37

    /etc/init.d/manual/S50sshd stop &> /dev/null
    /etc/init.d/manual/S10pppoe_server stop &> /dev/null
    ifconfig eth0 down
    /etc/init.d/manual/S60keyfill_led stop &> /dev/null
}

show_device_delete_dialog()
{
    rm -f /tmp/device_delete_dialog &>/dev/null
    touch /tmp/device_delete_dialog &>/dev/null

    HEIGHT=8
    for FILE in `get_all_dkeks`
    do
        DEVICE_SERIAL=`echo "$FILE" | sed -e "s|${DKEK_DIR}/||g" -e 's|.kek||g'`
        echo "\"$FILE\" \"$DEVICE_SERIAL\" off" >> /tmp/device_delete_dialog
        HEIGHT=$((HEIGHT<24 ? HEIGHT+1 : HEIGHT))
    done

    dialog \
    --title "Select Devices to Delete" \
    --no-tags \
    --checklist "Deleting a Device removes its Key Encryption Key. Once saved to the SD Card, this cannot be undone." "$HEIGHT" 60 4 \
    --file /tmp/device_delete_dialog
}

delete_devices()
{
    while true
    do
        if is_initialized
        then
            if show_device_delete_dialog 2>$ANSWER
            then
                if cat "$ANSWER" | xargs rm -f
                then
                    dialog --msgbox "Devices Deleted!" 0 0
                else
                    dialog --msgbox "Devices Not Deleted!" 0 0
                fi
            fi

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
        rm -f /tmp/key_opts
        rm -f /tmp/dev_opts
        touch /tmp/key_opts
        touch /tmp/dev_opts

        HEIGHT=17

        if has_any_black_keys
        then
            echo "F \"Enable Ethernet Key Fill\"" > /tmp/key_opts
            HEIGHT=$((HEIGHT+1))
        fi

        if has_any_dkeks
        then
            echo "V \"Delete Devices\"" > /tmp/dev_opts
            HEIGHT=$((HEIGHT+1))
        fi

        if dialog \
           --title "Configuration Options" \
           --hfile "/usr/share/help/config.txt" \
           --menu "Select an option. Press F1 for Help." "$HEIGHT" 60 4 \
           1 "Configure Radio Mode" \
           2 "Configure Radio Squelch" \
           3 "Configure Encryption" \
           4 "Configure TTS Alert Broadcasts" \
           5 "Configure Hardware" \
           6 "Set Configuration Menu Password" \
           A "Apply Current Settings" \
           R "Reinitialize System From SD Card" \
           S "Save Configuration To SD Card" \
           D "Deploy Images" \
           --file /tmp/dev_opts \
           --file /tmp/key_opts 2>$ANSWER
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
                    configure_password
                    ;;
                A)
                    apply_settings
                    ;;
                R)
                    password_prompt && load_from_sd A R E
                    ;;
                S)
                    save_to_sd A R E
                    ;;
                D)
                    write_image
                    ;;
                F)
                    run_key_fill
                    ;;
                V)
                    delete_devices
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

PASSWD_ATTEMPTS=0

password_prompt()
{
    while true
    do
        if is_initialized
        then
            PASSWD=`get_config_val Config ConfigPassword`
            if test -z "$PASSWD"
            then
                return 0
            else
                TITLE="Password Required"
                while true
                do
                    PASSWD_FILE=`mktemp`
                    if dialog \
                       --title "$TITLE" \
                       --passwordbox "Enter Configuration Menu Password" 8 60 2>"$PASSWD_FILE"
                    then
                        PASSWD_SALT=`echo "$PASSWD" | cut -d '$' -f 3`
                        DLG_PASSWD=`mkpasswd -P 0 -S "$PASSWD_SALT" -m sha512 < "$PASSWD_FILE"`
                        if test "$PASSWD" = "$DLG_PASSWD"
                        then
                            rm "$PASSWD_FILE"

                            PASSWD_ATTEMPTS=0

                            return 0
                        else
                            rm "$PASSWD_FILE"
                            TITLE="Incorrect Password"

                            PASSWD_ATTEMPTS=$((PASSWD_ATTEMPTS+1))
                            if test "$PASSWD_ATTEMPTS" -ge 3
                            then
                                disable_config
                                exit 0
                            fi

                            sleep 1
                        fi
                    else
                        rm "$PASSWD_FILE"
                        return 1
                    fi
                done
            fi
        elif ! dialog --yesno "Config Not Initialized! Retry?" 0 0
        then
            return 1
        fi
    done
}

configuration_menu_prompt()
{
    password_prompt && configuration_menu
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
            VAL="`get_config_val Codec Enabled`"

            if test "`get_config_val Crypto Enabled`" -ne 0
            then
                ANALOG_STR="Plain"
                if has_red_key "`get_key_index`"
                then
                    DIGITAL_STR="Secure"
                    INSECURE_MODE_STR="Plain"
                else
                    DIGITAL_STR="Insecure (No Key)"
                    INSECURE_MODE_STR="All"
                fi
            else
                DIGITAL_STR="Digital"
                ANALOG_STR="Analog"
                INSECURE_MODE_STR="All"
            fi

            dialog \
            --no-tags \
            --title "Select $DIGITAL_STR or $ANALOG_STR Transmission" \
            --radiolist "$INSECURE_MODE_STR transmissions will be sent in the clear." 9 60 3 \
            1       "$DIGITAL_STR" `on_off $VAL 1`  \
            0       "$ANALOG_STR"  `on_off $VAL 0` 2>$ANSWER

            option=`cat $ANSWER`
            case "$option" in
                0|1)
                    set_config_val Codec Enabled "$option"
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

load_keys()
{
    if ! sd_has_any_keys && ! usb_has_any_keys && dialog --yesno "Load Keys Using Ethernet?" 0 0
    then
        ifconfig eth0 up
        dialog --infobox "Enabling Ethernet..." 0 0

        COUNT=0
        while ! ethernet_link_detected && test "$COUNT" -lt 10
        do
            COUNT=$((COUNT+1))
            sleep 1
        done

        if ethernet_link_detected
        then
            /etc/init.d/manual/S10pppoe_client start &> /dev/null
            dialog --infobox "Connecting to Key Fill Device..." 0 0

            COUNT=0
            while ! pppoe_link_established
            do
                COUNT=$((COUNT+1))
                sleep 1
            done
        fi
    fi

    if load_sd_key_noclobber &> /dev/null
    then
        set_key_index "`next_key_idx 256`"
        set_dirty
        apply_settings

        /etc/init.d/manual/S10pppoe_client stop &> /dev/null
        dialog --msgbox "Keys Loaded!" 0 0
        ifconfig eth0 down

        return 0
    else

        /etc/init.d/manual/S10pppoe_client stop &> /dev/null
        dialog --msgbox "Keys Not Loaded!" 0 0
        ifconfig eth0 down

        return 1
    fi
}

radio_menu()
{
    while true
    do
        rm -f /tmp/transmit_opt
        rm -f /tmp/load_opt
        rm -f /tmp/shell_opt
        rm -f /tmp/config_opt
        touch /tmp/transmit_opt
        touch /tmp/load_opt
        touch /tmp/shell_opt
        touch /tmp/config_opt

        PTT_ENABLED=`get_config_val PTT Enabled`
        PTT_GPIONUM=`get_config_val PTT GPIONum`

        HEIGHT=13
        if test "$PTT_ENABLED" -ne 0 && test "$PTT_GPIONUM" -eq "-1"
        then
            echo "T \"Transmit Voice\"" > /tmp/transmit_opt
            HEIGHT=$((HEIGHT+1))
        fi

        if test "`get_config_val Crypto Enabled`" -ne 0
        then
            if has_red_key "`get_key_index`"
            then
                DIGITAL_STR="Secure"
            else
                DIGITAL_STR="Insecure (No Key)"
            fi
            ANALOG_STR="Plain"
        else
            DIGITAL_STR="Digital"
            ANALOG_STR="Analog"
        fi

        if ! has_any_keys
        then
            echo "L \"Load Keys\"" > /tmp/load_opt
        else
            echo "K \"Select Active Key\"" > /tmp/load_opt
        fi

        if test "`get_sys_config_val Diagnostics ShellEnabled`" -ne 0
        then
            echo "S \"Shell Access (Experts Only)\"" >> /tmp/shell_opt
            HEIGHT=$((HEIGHT+1))
        fi

        if config_enabled
        then
            echo "O \"Configuration Options\"" > /tmp/config_opt
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
           --file /tmp/load_opt \
           D "Select $DIGITAL_STR/$ANALOG_STR" \
           --file /tmp/config_opt \
           B "View Boot Messages" \
           --file /tmp/shell_opt 2>$ANSWER
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
                S)
                    clear && exec /sbin/getty -L "`tty`" 115200
                    ;;
                B)
                    show_boot_messages
                    ;;
                O)
                    configuration_menu_prompt
                    apply_settings
                    ;;
                L)
                    if ! has_any_keys
                    then
                        load_keys
                    fi
                    ;;
            esac
        else
            disable_config
            exit 0
        fi
    done
}

key_fill_menu()
{
    while true
    do
        rm -f /tmp/fill_opt
        rm -f /tmp/load_opt
        rm -f /tmp/del_opt
        rm -f /tmp/shell_opt
        touch /tmp/fill_opt
        touch /tmp/load_opt
        touch /tmp/del_opt
        touch /tmp/shell_opt

        HEIGHT=10

        if has_any_black_keys
        then
            echo "F \"Enable Ethernet Key Fill\"" > /tmp/fill_opt
        fi

        if ! has_any_keys
        then
            echo "L \"Load Keys\"" > /tmp/load_opt
        else
            echo "D \"Delete Keys\"" > /tmp/del_opt
            HEIGHT=$((HEIGHT+1))
        fi

        if test "`get_sys_config_val Diagnostics ShellEnabled`" -ne 0
        then
            echo "S \"Shell Access (Experts Only)\"" >> /tmp/shell_opt
            HEIGHT=$((HEIGHT+1))
        fi

        if dialog \
           --cancel-label "LOCK" \
           --title "Crypto Voice Module Key Fill Interface" \
           --menu "Select an option." $HEIGHT 60 4 \
           --file /tmp/fill_opt \
           --file /tmp/load_opt \
           C "Create Encryption Keys" \
           --file /tmp/del_opt \
           B "View Boot Messages" \
           --file /tmp/shell_opt 2>$ANSWER
        then
            option=`cat $ANSWER`
            case "$option" in
                F)
                    run_key_fill
                    ;;
                D)
                    delete_encryption_keys
                    ;;
                C)
                    generate_encryption_keys
                    ;;
                S)
                    clear && exec /sbin/getty -L "`tty`" 115200
                    ;;
                B)
                    show_boot_messages
                    ;;
                L)
                    if ! has_any_keys
                    then
                        load_keys
                    fi
                    ;;
            esac
        else
            disable_config
            exit 0
        fi
    done
}

main_menu()
{
    DEVICE_SERIAL=`get_device_serial`
    DIALOGOPTS="--backtitle \"Version: $VERSION"
    if test -n "$DEVICE_SERIAL"
    then
        DIALOGOPTS="$DIALOGOPTS Device Serial Number: $DEVICE_SERIAL\""
    else
        DIALOGOPTS="$DIALOGOPTS\""
    fi
    export DIALOGOPTS

    if key_fill_only
    then
        key_fill_menu
    else
        radio_menu
    fi
}

# ForceShowConfig setting must be turned on in the firmware itself
if (test "`get_sys_config_val Diagnostics ForceShowConfig`" -ne 0) ||
   (wait_initialized && test "`get_config_val Config Enabled`" -ne 0)
then
    main_menu
else
    DEVICE_SERIAL=`get_device_serial`
    if test -z "$DEVICE_SERIAL"
    then
        exec dialog --msgbox "Display Locked" 0 0
    else
        exec dialog --backtitle "Device Serial Number: $DEVICE_SERIAL" --msgbox "Display Locked" 0 0
    fi
fi

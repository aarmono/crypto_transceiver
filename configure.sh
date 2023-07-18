#!/usr/bin/env sh

. /etc/profile.d/shell_functions.sh

exec 2>/dev/null

ANSWER=/tmp/answer

on_off()
{
    test "$1" = "$2" && echo on || echo off
}

configure_ptt_enable()
{
    VAL=`get_user_config_val PTT Enabled`
    DEFAULT=`get_sys_config_val PTT Enabled`

    if test "$DEFAULT" = "0"
    then
        DEFAULT=Off
    else
        DEFAULT=On
    fi

    dialog \
    --no-tags \
    --title "Configure Push to Talk" \
    --radiolist "Select an option or \"Default\" to use the system default." 10 60 4 \
    default "Default ($DEFAULT)" `on_off $VAL ""` \
    1       "On"                 `on_off $VAL 1`  \
    0       "Off"                `on_off $VAL 0` 2>$ANSWER

    option=`cat $ANSWER`
    case "$option" in
        default)
            set_config_val PTT Enabled ""
            ;;
        0|1)
            set_config_val PTT Enabled $option
            ;;
    esac
}

configure_ptt_pin()
{
    VAL=`get_user_config_val PTT $2`
    DEFAULT=`get_sys_config_val PTT $2`

    dialog \
    --no-tags \
    --title "Configure PTT $1 Pin (See: https://pinout.xyz)" \
    --radiolist "Select an option or \"Default\" to use the system default." 36 60 4 \
    default "Default (GPIO $DEFAULT)" `on_off $VAL ""` \
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

    option=`cat $ANSWER`
    case "$option" in
        default)
            set_config_val PTT $2 ""
            ;;
        0|1|2|3|4|5|6|7|8|9| \
        10|11|12|13|14|15|16| \
        17|18|19|20|21|22|23| \
        24|25|26|27)
            set_config_val PTT $2 $option
            ;;
    esac
}

configure_ptt_bias()
{
    VAL=`get_user_config_val PTT $2`
    DEFAULT=`get_sys_config_val PTT $2`

    dialog \
    --no-tags \
    --title "Configure PTT $1 Bias" \
    --radiolist "Select an option or \"Default\" to use the system default." 11 60 4 \
    default   "Default ($DEFAULT)" `on_off $VAL ""` \
    pull-up   "Pull-up"            `on_off $VAL pull-up` \
    pull-down "Pull-down"          `on_off $VAL pull-down` \
    disable   "Disable"            `on_off $VAL disable` 2>$ANSWER

    option=`cat $ANSWER`
    case "$option" in
        default)
            set_config_val PTT $2 ""
            ;;
        pull-up|pull-down|disable)
            set_config_val PTT $2 $option
            ;;
    esac
}

configure_ptt_drive()
{
    VAL=`get_user_config_val PTT $2`
    DEFAULT=`get_sys_config_val PTT $2`

    dialog \
    --no-tags \
    --title "Configure PTT $1 Drive" \
    --radiolist "Select an option or \"Default\" to use the system default." 11 60 4 \
    default     "Default ($DEFAULT)" `on_off $VAL ""` \
    open-drain  "Open-drain"         `on_off $VAL open-drain` \
    open-source "Open-source"        `on_off $VAL open-source` \
    push-pull   "Push-pull"          `on_off $VAL push-pull` 2>$ANSWER

    option=`cat $ANSWER`
    case "$option" in
        default)
            set_config_val PTT $2 ""
            ;;
        open-drain|open-source|push-pull)
            set_config_val PTT $2 $option
            ;;
    esac
}

configure_ptt_active_level()
{
    VAL=`get_user_config_val PTT $2`
    DEFAULT=`get_sys_config_val PTT $2`

    if test "$DEFAULT" = "0"
    then
        DEFAULT="Active High"
    else
        DEFAULT="Active Low"
    fi

    dialog \
    --no-tags \
    --title "Configure PTT $1 Active Level" \
    --radiolist "Select an option or \"Default\" to use the system default." 10 60 4 \
    default "Default ($DEFAULT)" `on_off $VAL ""` \
    1       "Active Low"         `on_off $VAL 1`  \
    0       "Active High"        `on_off $VAL 0` 2>$ANSWER

    option=`cat $ANSWER`
    case "$option" in
        default)
            set_config_val PTT $2 ""
            ;;
        0|1)
            set_config_val PTT $2 $option
            ;;
    esac
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
                    configure_ptt_pin Input GPIONum
                    ;;
                3)
                    configure_ptt_bias Input Bias
                    ;;
                4)
                    configure_ptt_active_level Input ActiveLow
                    ;;
                5)
                    configure_ptt_pin Output OutputGPIONum
                    ;;
                6)
                    configure_ptt_bias Output OutputBias
                    ;;
                7)
                    configure_ptt_drive Output OutputDrive
                    ;;
                8)
                    configure_ptt_active_level Output OutputActiveLow
                    ;;
                "")
                    return
                    ;;
            esac
        elif ! dialog --yesno "Config Not Initialized! Retry? " 0 0
        then
            return
        fi
    done
}

configure_encryption()
{
    while true
    do
        if is_initialized
        then
            VAL=`get_user_config_val Crypto Enabled`
            DEFAULT=`get_sys_config_val Crypto Enabled`

            if test "$DEFAULT" = "0"
            then
                DEFAULT=Off
            else
                DEFAULT=On
            fi

            dialog \
            --no-tags \
            --title "Configure Encryption" \
            --radiolist "Select an option or \"Default\" to use the system default." 10 60 4 \
            default "Default ($DEFAULT)" `on_off $VAL ""` \
            1       "On"                 `on_off $VAL 1`  \
            0       "Off"                `on_off $VAL 0` 2>$ANSWER

            option=`cat $ANSWER`
            case "$option" in
                default)
                    set_config_val Crypto Enabled ""
                    ;;
                0|1)
                    set_config_val Crypto Enabled $option
                    ;;
            esac

            return
        elif ! dialog --yesno "Config Not Initialized! Retry? " 0 0
        then
            return
        fi
    done
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
                    ;;
                700C|700D|700E|800XA|1600|2400B)
                    set_config_val Codec Mode $option
                    ;;
            esac

            return
        elif ! dialog --yesno "Config Not Initialized! Retry? " 0 0
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
        if is_initialized
        then
            /etc/init.d/S31jack_crypto_rx stop &> /dev/null
            /etc/init.d/S30jack_crypto_tx stop &> /dev/null
            /etc/init.d/S29jackd_rx stop &> /dev/null
            /etc/init.d/S28jackd_tx stop &> /dev/null

            while /etc/init.d/S28jackd_tx running || /etc/init.d/S29jackd_rx running || \
                  /etc/init.d/S30jack_crypto_tx running || /etc/init.d/S31jack_crypto_rx running
            do
                sleep .1
            done

            /etc/init.d/S28jackd_tx start &> /dev/null
            /etc/init.d/S29jackd_rx start &> /dev/null
            /etc/init.d/S30jack_crypto_tx start &> /dev/null
            /etc/init.d/S31jack_crypto_rx start &> /dev/null

            return
        elif ! dialog --yesno "Config Not Initialized! Retry? " 0 0
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
        elif ! dialog --yesno "Config Not Initialized! Retry? " 0 0
        then
            return
        fi
    done
}

save_to_sd()
{
    while true
    do
        if is_initialized
        then
            if rm -f "$ASOUND_CFG" && alsactl store && \
               save_sd_sound_config && save_sd_crypto_config && \
               save_sd_key && save_sd_seed
            then
                apply_settings
                dialog --msgbox "Settings Saved!" 0 0
            else
                dialog --msgbox "Settings Not Saved!" 0 0
            fi

            return
        elif ! dialog --yesno "Config Not Initialized! Retry? " 0 0
        then
            return
        fi
    done
}

reload_from_sd()
{
    while true
    do
        if is_initialized
        then
            if load_sd_sound_config && load_sd_crypto_config && load_sd_key
            then
                alsa_restore
                apply_settings

                dialog --msgbox "Settings Reloaded!" 0 0
            else
                dialog --msgbox "Settings Not Reloaded!" 0 0
            fi

            return
        elif ! dialog --yesno "Config Not Initialized! Retry? " 0 0
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
        elif ! dialog --yesno "Config Not Initialized! Retry? " 0 0
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
            alsamixer -D "$DEV"
            return
        elif ! dialog --yesno "$2 Device $DEV Not Ready! Retry? " 0 0
        then
            return
        fi
    done
}

generate_encryption_key()
{
    while true
    do
        if is_initialized
        then
            if gen_key
            then
                dialog --msgbox "New Key Created!" 0 0
            else
                dialog --msgbox "New Key Not Created!" 0 0
            fi

            return
        elif ! dialog --yesno "Config Not Initialized! Retry? " 0 0
        then
            return
        fi
    done
}

main_menu()
{
    while true
    do
        dialog \
        --no-cancel \
        --title "Crypto Voice Module Configuration" \
        --hfile "/usr/share/help/config.txt" \
        --menu "Select an option. Press F1 for Help." 20 60 4 \
        0 "Configure Headset Volume" \
        1 "Configure Radio Volume" \
        2 "Configure Radio Mode" \
        3 "Configure Encryption" \
        4 "Configure Push to Talk" \
        5 "Assign Audio Devices" \
        6 "Generate Encryption Key" \
        V "View Current Settings" \
        A "Apply Current Settings" \
        R "Reload Settings From SD Card" \
        S "Save Current Settings to SD Card" \
        M "View Boot Messages" \
        L "Shell Access (Experts Only)" 2>$ANSWER

        option=`cat $ANSWER`
        case "$option" in
            0)
                start_alsamixer VoiceDevice Headset
                ;;
            1)
                start_alsamixer ModemDevice Radio
                ;;
            2)
                configure_mode
                ;;
            3)
                configure_encryption
                ;;
            4)
                configure_ptt
                ;;
            5)
                assign_audio_devices
                ;;
            6)
                generate_encryption_key
                ;;
            V)
                show_user_settings
                ;;
            A)
                apply_settings
                ;;
            R)
                reload_from_sd
                ;;
            S)
                save_to_sd
                ;;
            L)
                clear && exec /sbin/getty -L `tty` 115200
                ;;
            M)
                show_boot_messages
        esac
    done
}

dmesg -n 1

main_menu

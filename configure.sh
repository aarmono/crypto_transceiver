#!/usr/bin/env sh

. /etc/profile.d/shell_functions.sh

exec 2>/dev/null
set -o pipefail

ANSWER=/tmp/answer
SD_IMG=/tmp/sd.img
DIRTY=/tmp/dirty

alias set_dirty="touch $DIRTY"
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
    --title "Enable Push to Talk" \
    --radiolist "Select an option or \"Default\" to use the system default." 10 60 4 \
    default "Default ($DEFAULT)" `on_off $VAL ""` \
    1       "On"                 `on_off $VAL 1`  \
    0       "Off"                `on_off $VAL 0` 2>$ANSWER

    option=`cat $ANSWER`
    case "$option" in
        default)
            set_config_val PTT Enabled ""
            set_dirty
            ;;
        0|1)
            set_config_val PTT Enabled $option
            set_dirty
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
            set_dirty
            ;;
        0|1|2|3|4|5|6|7|8|9| \
        10|11|12|13|14|15|16| \
        17|18|19|20|21|22|23| \
        24|25|26|27)
            set_config_val PTT $2 $option
            set_dirty
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
            set_dirty
            ;;
        pull-up|pull-down|disable)
            set_config_val PTT $2 $option
            set_dirty
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
            set_dirty
            ;;
        open-drain|open-source|push-pull)
            set_config_val PTT $2 $option
            set_dirty
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
            set_dirty
            ;;
        0|1)
            set_config_val PTT $2 $option
            set_dirty
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
        elif ! dialog --yesno "Config Not Initialized! Retry?" 0 0
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
                    set_dirty
                    ;;
                0|1)
                    set_config_val Crypto Enabled $option
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
    VAL=`get_user_config_val Codec SquelchEnabled`
    DEFAULT=`get_sys_config_val Codec SquelchEnabled`

    if test "$DEFAULT" = "0"
    then
        DEFAULT=Off
    else
        DEFAULT=On
    fi

    dialog \
    --no-tags \
    --title "Enable Squelch" \
    --radiolist "Select an option or \"Default\" to use the system default." 10 60 4 \
    default "Default ($DEFAULT)" `on_off $VAL ""` \
    1       "On"                 `on_off $VAL 1`  \
    0       "Off"                `on_off $VAL 0` 2>$ANSWER

    option=`cat $ANSWER`
    case "$option" in
        default)
            set_config_val Codec SquelchEnabled ""
            set_dirty
            ;;
        0|1)
            set_config_val Codec SquelchEnabled $option
            set_dirty
            ;;
    esac
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
            set_dirty
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
        if test ! -e "$DIRTY"
        then
            return
        elif is_initialized
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

            rm -f "$DIRTY"

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
                            set_dirty
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

generate_encryption_key()
{
    while true
    do
        if is_initialized
        then
            if gen_key
            then
                set_dirty
                dialog --msgbox "New Key Created!" 0 0
            else
                dialog --msgbox "New Key Not Created!" 0 0
            fi

            return
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
            --title "Disable Configuration Utility?" \
            --radiolist "If Enabled, the Configuration Utility will be shown at startup. If Disabled, the display will be locked at startup. If Disabled and saved to the SD Card, it cannot be re-enabled once the system is turned off" 13 60 3 \
            default "Default ($DEFAULT)" `on_off $VAL ""` \
            1       "Enabled"            `on_off $VAL 1`  \
            0       "Disabled"           `on_off $VAL 0` 2>$ANSWER

            option=`cat $ANSWER`
            case "$option" in
                default)
                    set_config_val Config Enabled ""
                    set_dirty
                    ;;
                0|1)
                    set_config_val Config Enabled $option
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

main_menu()
{
    while true
    do
        if dialog \
           --cancel-label "EXIT" \
           --title "Crypto Voice Module Configuration" \
           --hfile "/usr/share/help/config.txt" \
           --menu "Select an option. Press F1 for Help." 23 60 4 \
           0 "Configure Headset Volume" \
           1 "Configure Radio Volume" \
           2 "Configure Radio Mode" \
           3 "Configure Radio Squelch" \
           4 "Configure Encryption" \
           5 "Configure Push to Talk" \
           6 "Assign Audio Devices" \
           7 "Generate Encryption Key" \
           8 "Disable Configuration Utility" \
           V "View Current Settings" \
           A "Apply Current Settings" \
           R "Reload Settings From SD Card" \
           S "Save Current Settings to SD Card" \
           C "Advanced SD Card Operations" \
           M "View Boot Messages" \
           L "Shell Access (Experts Only)" 2>$ANSWER
        then
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
                    configure_squelch
                    ;;
                4)
                    configure_encryption
                    ;;
                5)
                    configure_ptt
                    ;;
                6)
                    assign_audio_devices
                    ;;
                7)
                    generate_encryption_key
                    ;;
                8)
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
                L)
                    clear && exec /sbin/getty -L `tty` 115200
                    ;;
                M)
                    show_boot_messages
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

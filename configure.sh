#!/usr/bin/env sh

ANSWER=/tmp/answer

on_off()
{
  if [ "$1" = "$2" ] ; then echo on ; else echo off ; fi
}

configure_ptt_enable()
{
    VAL=`iniget PTT Enabled /etc/crypto.ini.sd`
    DEFAULT=`iniget PTT Enabled /etc/crypto.ini`

    if [ "$DEFAULT" = "0" ]
    then
        DEFAULT=Off
    else
        DEFAULT=On
    fi

    dialog \
    --no-tags \
    --title "Configure Push to Talk" \
    --radiolist "Select an Option" 10 60 4 \
    default "Default ($DEFAULT)" `on_off $VAL ""` \
    1       "On"                 `on_off $VAL 1`  \
    0       "Off"                `on_off $VAL 0` 2>$ANSWER

    option=`cat $ANSWER`
    case "$option" in
        default)
            iniset PTT Enabled "" /etc/crypto.ini.sd
            ;;
        0|1)
            iniset PTT Enabled $option /etc/crypto.ini.sd
            ;;
    esac
}

configure_ptt_pin()
{
    VAL=`iniget PTT $2 /etc/crypto.ini.sd`
    DEFAULT=`iniget PTT $2 /etc/crypto.ini`

    dialog \
    --no-tags \
    --title "Configure PTT $1 Pin (See: https://pinout.xyz)" \
    --radiolist "Select an Option" 36 60 4 \
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
            iniset PTT $2 "" /etc/crypto.ini.sd
            ;;
        0|1|2|3|4|5|6|7|8|9| \
        10|11|12|13|14|15|16| \
        17|18|19|20|21|22|23| \
        24|25|26|27)
            iniset PTT $2 $option /etc/crypto.ini.sd
            ;;
    esac
}

configure_ptt_bias()
{
    VAL=`iniget PTT $2 /etc/crypto.ini.sd`
    DEFAULT=`iniget PTT $2 /etc/crypto.ini`

    dialog \
    --no-tags \
    --title "Configure PTT $1 Bias" \
    --radiolist "Select an Option" 11 60 4 \
    default   "Default ($DEFAULT)" `on_off $VAL ""` \
    pull-up   "pull-up"            `on_off $VAL pull-up` \
    pull-down "pull-down"          `on_off $VAL pull-down` \
    disable   "disable"            `on_off $VAL disable` 2>$ANSWER

    option=`cat $ANSWER`
    case "$option" in
        default)
            iniset PTT $2 "" /etc/crypto.ini.sd
            ;;
        pull-up|pull-down|disable)
            iniset PTT $2 $option /etc/crypto.ini.sd
            ;;
    esac
}

configure_ptt_drive()
{
    VAL=`iniget PTT $2 /etc/crypto.ini.sd`
    DEFAULT=`iniget PTT $2 /etc/crypto.ini`

    dialog \
    --no-tags \
    --title "Configure PTT $1 Drive" \
    --radiolist "Select an Option" 11 60 4 \
    default     "Default ($DEFAULT)" `on_off $VAL ""` \
    open-drain  "open-drain"         `on_off $VAL open-drain` \
    open-source "open-source"        `on_off $VAL open-source` \
    push-pull   "push-pull"          `on_off $VAL push-pull` 2>$ANSWER

    option=`cat $ANSWER`
    case "$option" in
        default)
            iniset PTT $2 "" /etc/crypto.ini.sd
            ;;
        open-drain|open-source|push-pull)
            iniset PTT $2 $option /etc/crypto.ini.sd
            ;;
    esac
}

configure_ptt_active_level()
{
    VAL=`iniget PTT $2 /etc/crypto.ini.sd`
    DEFAULT=`iniget PTT $2 /etc/crypto.ini`

    if [ "$DEFAULT" = "0" ]
    then
        DEFAULT="Active High"
    else
        DEFAULT="Active Low"
    fi

    dialog \
    --no-tags \
    --title "Configure PTT $1 Active Level" \
    --radiolist "Select an Option" 10 60 4 \
    default "Default ($DEFAULT)" `on_off $VAL ""` \
    1       "Active Low"         `on_off $VAL 1`  \
    0       "Active High"        `on_off $VAL 0` 2>$ANSWER

    option=`cat $ANSWER`
    case "$option" in
        default)
            iniset PTT $2 "" /etc/crypto.ini.sd
            ;;
        0|1)
            iniset PTT $2 $option /etc/crypto.ini.sd
            ;;
    esac
}

configure_ptt()
{
    while [ true ]
    do
        dialog \
        --title "PTT Configuration" \
        --menu "Select an option:" 15 60 4 \
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
    done
}

configure_encryption()
{
    VAL=`iniget Crypto Enabled /etc/crypto.ini.sd`
    DEFAULT=`iniget Crypto Enabled /etc/crypto.ini`

    if [ "$DEFAULT" = "0" ]
    then
        DEFAULT=Off
    else
        DEFAULT=On
    fi

    dialog \
    --no-tags \
    --title "Configure Encryption" \
    --radiolist "Select an Option" 10 60 4 \
    default "Default ($DEFAULT)" `on_off $VAL ""` \
    1       "On"                 `on_off $VAL 1`  \
    0       "Off"                `on_off $VAL 0` 2>$ANSWER

    option=`cat $ANSWER`
    case "$option" in
        default)
            iniset Crypto Enabled "" /etc/crypto.ini.sd
            ;;
        0|1)
            iniset Crypto Enabled $option /etc/crypto.ini.sd
            ;;
    esac
}

configure_mode()
{
    VAL=`iniget Codec Mode /etc/crypto.ini.sd`
    DEFAULT=`iniget Codec Mode /etc/crypto.ini`

    dialog \
    --no-tags \
    --title "Configure Radio Mode" \
    --radiolist "Select a Mode" 14 60 4 \
    default "Default ($DEFAULT)"    `on_off $VAL ""`    \
    700C    "700C (HF/SSB)"         `on_off $VAL 700C`  \
    700D    "700D (HF/SSB)"         `on_off $VAL 700D`  \
    700E    "700E (HF/SSB)"         `on_off $VAL 700E`  \
    800XA   "800XA (Any)"           `on_off $VAL 800XA` \
    1600    "1600 (HF/SSB)"         `on_off $VAL 1600`  \
    2400B   "2400B (Narrowband FM)" `on_off $VAL 2400B` 2>$ANSWER

    option=`cat $ANSWER`
    case "$option" in
        default)
            iniset Codec Mode "" /etc/crypto.ini.sd
            ;;
        700C|700D|700E|800XA|1600|2400B)
            iniset Codec Mode $option /etc/crypto.ini.sd
            ;;
    esac
}

save_to_sd()
{
    if alsactl store && \
       mcopy -t -D o -i /dev/mmcblk0p1 /var/lib/alsa/asound.state ::config/asound.state && \
       mcopy -t -D o -i /dev/mmcblk0p1 /etc/crypto.ini.sd ::config/crypto.ini
    then
        cat /etc/crypto.ini /etc/crypto.ini.sd > /etc/crypto.ini.all && killall -SIGHUP jack_crypto_tx jack_crypto_rx
        dialog --msgbox "Settings Saved!" 10 30
    else
        dialog --msgbox "Settings Not Saved!" 10 30
    fi
}

main_menu()
{
    while [ true ]
    do
        dialog \
        --no-cancel \
        --title "Crypto Voice Module Configuration" \
        --menu "Select an option:" 15 60 4 \
        1 "Configure Headset Volume" \
        2 "Configure Radio Volume" \
        3 "Configure Radio Mode" \
        4 "Configure Encryption" \
        5 "Configure Push to Talk" \
        6 "View SD Card Settings" \
        7 "Save Settings to SD Card" \
        8 "Login shell (Advanced Users Only)" 2>$ANSWER

        option=`cat $ANSWER`
        case "$option" in
            1)
                alsamixer -c 0
                ;;
            2)
                alsamixer -c 1
                ;;
            3)
                configure_mode
                ;;
            4)
                configure_encryption
                ;;
            5)
                configure_ptt
                ;;
            6)
                dialog \
                --title "SD Card Settings" \
                --textbox /etc/crypto.ini.sd 30 80
                ;;
            7)
                save_to_sd
                ;;
            8)
                /sbin/getty -L tty1 115200 vt100
                ;;
        esac
    done
}

while [ $((`aplay -l | grep -c card`)) -lt 2 ]
do
    sleep .5
done

main_menu

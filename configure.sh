#!/usr/bin/env sh

set_encryption ()
{
    iniset Crypto Enabled $1 /etc/crypto.ini.sess && cat /etc/crypto.ini /etc/crypto.ini.sd /etc/crypto.ini.sess > /etc/crypto.ini.all
    killall -SIGHUP jack_crypto_tx jack_crypto_rx
}

disable_encryption ()
{
    set_encryption 0
}

enable_encryption ()
{
    set_encryption 1
}

toggle_encryption()
{
    VAL=`iniget Crypto Enabled /etc/crypto.ini.sess /etc/crypto.ini.sd /etc/crypto.ini`
    VAL=$(((VAL!=0)^1))
    set_encryption $VAL
}

while [ $((`aplay -l | grep -c card`)) -lt 2 ]
do
    sleep .5
done

while [ true ]
do
    clear
    read -p 'Type "0" for headset, "1" for radio, or "s" to save and press Enter: ' option
    case "$option" in
        0)
            alsamixer -c 0
            ;;
        1)
            alsamixer -c 1
            ;;
        s)
            alsactl store && mcopy -t -D o -i /dev/mmcblk0p1 /var/lib/alsa/asound.state ::config/asound.state
            ;;
        p)
            disable_encryption
            ;;
        c)
            enable_encryption
            ;;
        l)
            /sbin/getty -L tty1 115200 vt100
            ;;
        *)
            "Invalid option"
            ;;
    esac
done


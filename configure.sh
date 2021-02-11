#!/usr/bin/env sh

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
            if [ $? = 0 ]
            then
                aplay -q -t wav -D "plug:headset" /usr/share/sounds/ack.wav
            else
                aplay -q -t wav -D "plug:headset" /usr/share/sounds/nack.wav
            fi
            ;;
        p)
            sed 's/^[[:blank:]]*KeyFile/;KeyFile/' /etc/crypto_tx.ini > /etc/crypto_tx.ini.new && mv /etc/crypto_tx.ini.new /etc/crypto_tx.ini
            sed 's/^[[:blank:]]*KeyFile/;KeyFile/' /etc/crypto_rx.ini > /etc/crypto_rx.ini.new && mv /etc/crypto_rx.ini.new /etc/crypto_rx.ini
            killall -SIGHUP crypto_tx && killall -SIGHUP crypto_rx
            ;;
        c)
            sed 's/^[[:blank:]]*;[[:blank:]]*KeyFile/KeyFile/' /etc/crypto_tx.ini > /etc/crypto_tx.ini.new && mv /etc/crypto_tx.ini.new /etc/crypto_tx.ini
            sed 's/^[[:blank:]]*;[[:blank:]]*KeyFile/KeyFile/' /etc/crypto_rx.ini > /etc/crypto_rx.ini.new && mv /etc/crypto_rx.ini.new /etc/crypto_rx.ini
            killall -SIGHUP crypto_tx && killall -SIGHUP crypto_rx
            ;;
        l)
            /sbin/getty -L tty1 115200 vt100
            ;;
        *)
            "Invalid option"
            ;;
    esac
done


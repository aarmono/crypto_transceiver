#!/usr/bin/env sh

. /etc/profile.d/shell_functions.sh

toggle_keyfill()
{
    if /etc/init.d/manual/S10pppoe_server running
    then
        /etc/init.d/manual/S50sshd stop
        /etc/init.d/manual/S10pppoe_server stop
        ifconfig eth0 down
        /etc/init.d/manual/S60keyfill_led stop
    else
        ifconfig eth0 up
        /etc/init.d/manual/S10pppoe_server start
        /etc/init.d/manual/S50sshd start
        /etc/init.d/manual/S60keyfill_led start
    fi
}

can_toggle_keyfill()
{
    has_any_keys && ! /etc/init.d/S10pppoe_client running
}

while read -r button event
do
    case "$event" in
        update)
            case "$button" in
                d)
                    if can_toggle_keyfill
                    then
                        toggle_keyfill
                    fi
                    ;;
            esac
            ;;
    esac
done

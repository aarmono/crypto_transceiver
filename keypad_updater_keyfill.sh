#!/usr/bin/env sh

. /etc/profile.d/shell_functions.sh

error_blink()
{
    for i in `seq 1 3`
    do
        start_keyfill_led.sh 50000
        sleep .05
    done
}

can_toggle_keyfill()
{
    has_any_black_keys && ! /etc/init.d/manual/S10pppoe_client running
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
                    else
                        error_blink
                    fi
                    ;;
            esac
            ;;
    esac
done

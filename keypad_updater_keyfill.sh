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

load_keys()
{
    if load_ext_key_noclobber
    then
        /etc/init.d/manual/S10pppoe_client stop
        ifconfig eth0 down
        confirm_blink 2
    else
        /etc/init.d/manual/S10pppoe_client stop
        ifconfig eth0 down
        error_blink
    fi
}

load_dkeks()
{
    if load_ext_dkek
    then
        /etc/init.d/manual/S10pppoe_client stop
        ifconfig eth0 down
        confirm_blink 1
    else
        /etc/init.d/manual/S10pppoe_client stop
        ifconfig eth0 down
        error_blink
    fi
}

# $1: Number of times to blink (Default: 1)
confirm_blink()
{
    if test "$1" -gt 1
    then
        TIMES="$1"
    else
        TIMES=1
    fi

    for i in `seq 1 "$TIMES"`
    do
        start_keyfill_led.sh 10000
        sleep .1
    done
}

error_blink()
{
    for i in `seq 1 3`
    do
        start_keyfill_led.sh 50000
        sleep .05
    done
}

long_blink()
{
    start_keyfill_led.sh 1000000
}

can_toggle_keyfill()
{
    has_any_black_keys && ! /etc/init.d/manual/S10pppoe_client running
}

while read -r button event
do
    case "$event" in
        alert)
            case "$button" in
                a|b)
                    rm -f /etc/keys/*
                    SUCCESS=$?

                    if /etc/init.d/manual/S60keyfill_led running && /etc/init.d/manual/S60keyfill_led stop
                    then
                        if test "$SUCCESS" -eq 0
                        then
                            sleep 1
                        else
                            sleep .25 && error_blink
                        fi
                        /etc/init.d/manual/S60keyfill_led start
                    else
                        if test "$SUCCESS" -eq 0
                        then
                            long_blink
                        else
                            error_blink
                        fi
                    fi
                    ;;
             esac
             ;;
        reset)
            case "$button" in
                a|b)
                    /etc/init.d/manual/S10pppoe_client stop
                    ifconfig eth0 down
                    ;;
            esac
            ;;
        select)
            if ! /etc/init.d/manual/S10pppoe_server running
            then
                case "$button" in
                    a)
                        ifconfig eth0 up
                        confirm_blink 1
                        ;;
                    b)
                        if ! has_any_keys
                        then
                            ifconfig eth0 up
                            confirm_blink 2
                        else
                            error_blink
                        fi
                        ;;
                esac
            fi
            ;;
        value)
            if ! /etc/init.d/manual/S10pppoe_server running
            then
                case "$button" in
                    a)
                        if ext_has_any_dkeks
                        then
                            /etc/init.d/manual/S10pppoe_client start
                            /etc/init.d/manual/S10pppoe_client start
                            confirm_blink 1
                        else
                            error_blink
                        fi
                        ;;
                    b)
                        if ! has_any_keys && ext_has_any_keys
                        then
                            /etc/init.d/manual/S10pppoe_client start
                            confirm_blink 2
                        else
                            error_blink
                        fi
                        ;;
                esac
            fi
            ;;
        update)
            case "$button" in
                a)
                    if ! /etc/init.d/manual/S10pppoe_server running
                    then
                        if ext_has_any_dkeks
                        then
                            load_dkeks
                        else
                            error_blink
                        fi
                    fi
                    ;;
                b)
                    if ! /etc/init.d/manual/S10pppoe_server running
                    then
                        if ! has_any_keys && ext_has_any_keys
                        then
                            load_keys
                        else
                            error_blink
                        fi
                    fi
                    ;;
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

#!/usr/bin/env sh

RESTART=1

_term() {
    kill -TERM "$child"
    RESTART=0
}

while [ $RESTART -ne 0 ]
do

    while [ $((`aplay -l | grep -c card`)) -lt 2 ]
    do
        sleep .5
    done

    trap _term SIGTERM

    # Record buffer is 40ms; Play buffer is 80ms. A frame length in crypto_tx and
    # crypto_rx is 40ms
    SAMPLE_RATE=`crypto_sample_rate /etc/crypto_rx.ini`
    arecord -B 40000 -t raw -r $SAMPLE_RATE -c 1 -f S16_LE -D "plughw:1,0" - | crypto_rx /etc/crypto_rx.ini | aplay -B 80000 -t raw -r 8000 -c 1 -f S16_LE -D "plug:headset" - &
    child=$!
    wait "$child"

done

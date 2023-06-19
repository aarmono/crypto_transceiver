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
    SAMPLE_RATE=`crypto_sample_rate /etc/crypto_tx.ini`
    record_voice.sh | crypto_tx /etc/crypto_tx.ini | aplay -B 160000 -t raw -r $SAMPLE_RATE -c 1 -f S16_LE -D "plughw:1,0" - &
    child=$!
    aplay -t wav -D "plug:headset" /usr/share/sounds/startup.wav
    wait "$child"

done

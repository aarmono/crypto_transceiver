#!/usr/bin/env sh

_term() {
    kill -TERM "$child"
}

while [ $((`aplay -l | grep -c card`)) -lt 2 ]
do
    sleep .5
done

trap _term SIGTERM

arecord -t raw -r 48000 -c 1 -f S16_LE -D "plughw:1,0" - | crypto_rx /etc/crypto_rx.ini | aplay -t raw -r 8000 -c 1 -f S16_LE -D "plughw:0,0" - &
child=$!
wait "$child"

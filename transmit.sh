#!/usr/bin/env sh

_term() {
    kill -TERM "$child"
}

while [ $((`aplay -l | grep -c card`)) -lt 2 ]
do
    sleep .5
done

trap _term SIGTERM

# Record buffer is 40ms; Play buffer is 80ms. A frame length in crypto_tx and
# crypto_rx is 40ms
arecord -B 40000 -t raw -r 8000 -c 1 -f S16_LE -D "plughw:0,0" -  | sox -t raw -r 8000 -c 1 -b 16 -e signed-integer --buffer 640 - -t raw - sinc 400 lowpass 3000 | crypto_tx /etc/crypto_tx.ini | aplay -B 160000 -t raw -r 48000 -c 1 -f S16_LE -D "plughw:1,0" - &
child=$!
aplay -t wav -D "plug:headset" /usr/share/sounds/startup.wav
wait "$child"

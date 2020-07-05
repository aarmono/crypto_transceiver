#!/usr/bin/env sh

arecord -t raw -r 8000 -c 1 -f S16_LE -D "plughw:0,0" - | crypto_tx /etc/crypto_tx.ini | aplay -t raw -r 48000 -c 1 -f S16_LE -D "plughw:1,0" -
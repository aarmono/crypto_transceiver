#!/usr/bin/env sh
trap 'exit 0' INT TERM

while jack_wait -s rx -c | grep -q "not running"
do
    sleep .1
done

exec jack_crypto_rx rx /etc/crypto.ini.all

#!/usr/bin/env sh
trap 'exit 0' INT TERM

while jack_wait -s tx -c | grep -q "not running"
do
    sleep .1
done

exec jack_crypto_tx tx /etc/crypto.ini.all

#!/usr/bin/env sh
trap "kill %1; exit" INT TERM

jack_wait -s tx -w &
wait

exec jack_crypto_tx tx /etc/crypto.ini.all

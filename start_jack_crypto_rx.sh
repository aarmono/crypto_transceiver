#!/usr/bin/env sh
trap "kill %1; exit" INT TERM

jack_wait -s rx -w &
wait

exec jack_crypto_rx rx /etc/crypto.ini.all

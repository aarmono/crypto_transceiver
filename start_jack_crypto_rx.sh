#!/usr/bin/env sh

jack_wait -s rx -w

exec jack_crypto_rx rx /etc/crypto.ini

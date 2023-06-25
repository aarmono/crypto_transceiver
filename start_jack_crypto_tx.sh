#!/usr/bin/env sh

jack_wait -s tx -w

exec jack_crypto_tx tx /etc/crypto.ini.all

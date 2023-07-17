#!/usr/bin/env sh
trap 'exit 0' INT TERM

. /etc/profile.d/shell_functions.sh

wait_jackd tx

exec jack_crypto_tx tx /etc/crypto.ini.all

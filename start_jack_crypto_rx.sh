#!/usr/bin/env sh
trap 'exit 0' INT TERM

. /etc/profile.d/shell_functions.sh

wait_jackd rx

exec jack_crypto_rx rx /etc/crypto.ini.all

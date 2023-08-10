#!/usr/bin/env sh
trap 'exit 0' INT TERM

. /etc/profile.d/shell_functions.sh

wait_initialized

# If this is just a Key Fill device, do nothing
if key_fill_only
then
    exec sleep 365d
fi

wait_jackd rx

exec jack_crypto_rx rx /etc/crypto.ini.all

#!/usr/bin/env sh

# Record buffer is 80ms; A frame length in crypto_tx and crypto_rx is 40ms
# Equalizer emulates a Baofeng UV-82c at low power in VHF. See here:
# https://fcc.report/FCC-ID/ZP5BF-82/2153201
export AUDIODRIVER=alsa
export AUDIODEV="plughw:0,0"
exec rec -t raw -r 8000 -c 1 -b 16 -e signed-integer --buffer 640 --effects-file /etc/equalizers/uv-82c.txt -q -
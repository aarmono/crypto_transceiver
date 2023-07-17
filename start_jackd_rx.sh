#!/usr/bin/env sh
trap 'exit 0' INT TERM

. /etc/profile.d/shell_functions.sh

wait_initialized

IN_HW=`get_sound_hw_device ModemDevice`
OUT_HW=`get_sound_hw_device VoiceDevice`

wait_sound_dev_active_all "$IN_HW" "$OUT_HW"

if test "$IN_HW" = "$OUT_HW"
then
    HW_ARGS="-d $IN_HW"
else
    HW_ARGS="-C $IN_HW -P $OUT_HW"
fi

SAMPLE_RATE=`get_config_val JACK SampleRateRX`
BUFFERS=`get_config_val JACK NumBuffersRX`

exec jackd -n rx -d alsa $HW_ARGS -r "$SAMPLE_RATE" -p 1024 -n "$BUFFERS"

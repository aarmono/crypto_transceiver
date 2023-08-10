#!/usr/bin/env sh
trap 'exit 0' INT TERM

. /etc/profile.d/shell_functions.sh

echo "Wait for Config Initialization"
wait_initialized

# If this is just a Key Fill device, do nothing
if key_fill_only
then
    exec sleep 365d
fi

IN_HW=`get_sound_hw_device VoiceDevice`
OUT_HW=`get_sound_hw_device ModemDevice`

echo "Wait for Sound Cards"
wait_sound_dev_active_all "$IN_HW" "$OUT_HW" &>/dev/null

if test "$IN_HW" = "$OUT_HW"
then
    HW_ARGS="-d $IN_HW"
else
    HW_ARGS="-C $IN_HW -P $OUT_HW"
fi

SAMPLE_RATE=`get_config_val JACK SampleRateTX`
BUFFERS=`get_config_val JACK NumBuffersTX`

exec jackd -n tx -d alsa $HW_ARGS -r "$SAMPLE_RATE" -p 1024 -n "$BUFFERS"

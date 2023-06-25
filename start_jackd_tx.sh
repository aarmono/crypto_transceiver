#!/usr/bin/env sh

while [ $((`aplay -l | grep -c card`)) -lt 2 ]
do
    sleep .5
done

IN_HW=`iniget /etc/crypto.ini JACK VoiceInDevice`
OUT_HW=`iniget /etc/crypto.ini JACK ModemOutDevice`

if [ "$IN_HW" = "$OUT_HW" ]
then
    HW_ARGS="-d $IN_HW"
else
    HW_ARGS="-C $IN_HW -P $OUT_HW"
fi

SAMPLE_RATE=`iniget /etc/crypto.ini JACK SampleRateTX`

exec jackd -n tx -d alsa $HW_ARGS -r "$SAMPLE_RATE" -p 1024

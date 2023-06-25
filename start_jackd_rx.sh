#!/usr/bin/env sh

while [ $((`aplay -l | grep -c card`)) -lt 2 ]
do
    sleep .5
done

IN_HW=`iniget JACK ModemInDevice /etc/crypto.ini.sd /etc/crypto.ini`
OUT_HW=`iniget JACK VoiceOutDevice /etc/crypto.ini.sd /etc/crypto.ini`

if [ "$IN_HW" = "$OUT_HW" ]
then
    HW_ARGS="-d $IN_HW"
else
    HW_ARGS="-C $IN_HW -P $OUT_HW"
fi

SAMPLE_RATE=`iniget JACK SampleRateRX /etc/crypto.ini.sd /etc/crypto.ini`
BUFFERS=`iniget JACK NumBuffers /etc/crypto.ini.sd /etc/crypto.ini`

exec jackd -n rx -d alsa $HW_ARGS -r "$SAMPLE_RATE" -p 1024 -n "$BUFFERS"

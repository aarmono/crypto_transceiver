#!/usr/bin/env sh
trap 'exit 0' INT TERM

dev_active()
{
    if echo "$1" | grep -q USB
    then
        aplay -l | grep -q "$1"
    else
        aplay -l | grep -q "card $1"
    fi
}

while [ ! -e /var/run/initialized ]
do
    inotifywait -qq -t 1 --include initialized -e create /var/run/
done

IN_HW=`iniget JACK VoiceDevice /etc/crypto.ini.sd /etc/crypto.ini`
OUT_HW=`iniget JACK ModemDevice /etc/crypto.ini.sd /etc/crypto.ini`

IN_DEV=`echo "$IN_HW" | sed -e 's/hw://g'`
OUT_DEV=`echo "$OUT_HW" | sed -e 's/hw://g'`

while ! dev_active "$IN_DEV" || ! dev_active "$OUT_DEV"
do
    sleep .1
done

if [ "$IN_HW" = "$OUT_HW" ]
then
    HW_ARGS="-d $IN_HW"
else
    HW_ARGS="-C $IN_HW -P $OUT_HW"
fi

SAMPLE_RATE=`iniget JACK SampleRateTX /etc/crypto.ini.sd /etc/crypto.ini`
BUFFERS=`iniget JACK NumBuffersTX /etc/crypto.ini.sd /etc/crypto.ini`

exec jackd -n tx -d alsa $HW_ARGS -r "$SAMPLE_RATE" -p 1024 -n "$BUFFERS"

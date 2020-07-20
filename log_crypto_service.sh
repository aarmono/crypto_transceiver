#!/usr/bin/env sh

_term() {
    kill -TERM "$child"
}

LOGFILE="$1"

if [ -e "$LOGFILE" ] && [ ! -p "$LOGFILE" ]
then
    rm "$LOGFILE"
fi

if [ ! -e "$LOGFILE" ]
then
    mkfifo "$LOGFILE"
fi

while [ $((`aplay -l | grep -c card`)) -lt 2 ]
do
    sleep .5
done

trap _term SIGTERM

stdbuf -i0 -o0 cut -d ' ' -f 3- "$LOGFILE" | espeak -w /dev/stdout | aplay -t wav -D "plug:headset" - &
child=$!
wait "$child"

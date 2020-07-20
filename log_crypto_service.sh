#!/usr/bin/env sh

TERMINATE=0
_term() {
    TERMINATE=1
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

while [ $((TERMINATE)) -eq 0 ]
do
    stdbuf -i0 -o0 cut -d ' ' -f 3- "$LOGFILE" | espeak -w /dev/stdout | aplay -t wav -D "plug:headset" - &
    child=$!
    wait "$child"
done

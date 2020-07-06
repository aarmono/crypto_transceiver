#!/usr/bin/env sh

while [ $((`aplay -l | grep -c card`)) -lt 2 ]
do
    sleep .5
done

alsactl restore

#!/usr/bin/env sh

# Seed the RNG with random data from the SD card, if available
# Do this before the wait loop so it's done as early in the boot
# process as possible
mcopy -D o -n -i /dev/mmcblk0p1 ::seed /var/run/random-seed && dd if=/var/run/random-seed of=/dev/urandom

while [ $((`aplay -l | grep -c card`)) -lt 2 ]
do
    sleep .5
done

alsactl restore

# Put a new seed onto the SD card. This call will block until the RNG is
# initialized, so this needs to run in a background process (it is)
# Do this at the end so the alsactl call isn't blocked by it
dd if=/dev/random of=/var/run/random-seed bs=512 count=1 && mcopy -D o -n -i /dev/mmcblk0p1 /var/run/random-seed ::seed

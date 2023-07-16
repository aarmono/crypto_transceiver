#!/usr/bin/env sh
trap 'exit 0' INT TERM

echo "0" > /sys/class/leds/led0/brightness
echo "0" > /sys/class/leds/led1/brightness

# Wait for the SD card to be available
while [ ! -b /dev/mmcblk0p1 ]
do
    sleep .1
done

# Seed the RNG with random data from the SD card, if available
echo "Seeding RNG"
mcopy -D o -n -i /dev/mmcblk0p1 ::seed /var/run/random-seed && dd if=/var/run/random-seed of=/dev/urandom bs=512

echo "Loading sound configuration..."
mcopy -t -n -D o -i /dev/mmcblk0p1 ::config/asound.state /var/lib/alsa/asound.state

echo "Loading key..."
mcopy -D o -n -i /dev/mmcblk0p1 ::config/key /etc/key

echo "Loading crypto configuration..."
cp /etc/crypto.ini /etc/crypto.ini.all && mcopy -t -n -D o -i /dev/mmcblk0p1 ::config/crypto.ini /etc/crypto.ini.sd && cat /etc/crypto.ini /etc/crypto.ini.sd > /etc/crypto.ini.all

echo "Loading shadow..."
mcopy -t -n -D o -i /dev/mmcblk0p1 ::config/shadow /etc/shadow && chown root:root /etc/shadow && chmod 000 /etc/shadow

touch /var/run/initialized
echo "Done"

# Put a new seed onto the SD card. This call will block until the RNG is
# initialized, so this needs to run in a background process (it is)
dd if=/dev/random of=/var/run/random-seed bs=512 count=1 && mcopy -D o -n -i /dev/mmcblk0p1 /var/run/random-seed ::seed

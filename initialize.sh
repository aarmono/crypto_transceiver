#!/usr/bin/env sh
trap 'exit 0' INT TERM

. /etc/profile.d/shell_functions.sh

echo "0" > /sys/class/leds/led0/brightness
echo "0" > /sys/class/leds/led1/brightness

# Wait for the SD card to be available
wait_sd

# Seed the RNG with random data from the SD card, if available
echo "Seeding RNG"
seed_rng_with_sd

echo "Loading sound configuration..."
load_sd_sound_config

echo "Loading key..."
load_sd_key

echo "Loading crypto configuration..."
load_sd_crypto_config

echo "Loading shadow..."
mcopy_text ::config/shadow /etc/shadow && chown root:root /etc/shadow && chmod 000 /etc/shadow

touch /var/run/initialized
echo "Done"

# Put a new seed onto the SD card. This call will block until the RNG is
# initialized, so this needs to run in a background process (it is)
save_sd_seed

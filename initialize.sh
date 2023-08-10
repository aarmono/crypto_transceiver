#!/usr/bin/env sh
trap 'exit 0' INT TERM

. /etc/profile.d/shell_functions.sh

exec 2>/var/log/initialize.err

function main()
{
    echo "0" > /sys/class/leds/led0/brightness
    echo "0" > /sys/class/leds/led1/brightness

    # Wait for the SD card to be available
    wait_sd

    # Check if there is a config dir on the SD card and create it
    # if it does not exist
    echo -n "Checking for config dir..." && ensure_sd_has_config_dir && echo "Done!" || echo "Not found."

    # Seed the RNG with random data from the SD card, if available
    echo -n "Seeding RNG..." && seed_rng_with_sd && echo "Done!"

    echo -n "Loading sound configuration..." && load_sd_sound_config && echo "Done!" || echo "Not found."

    echo -n "Loading key..." && load_sd_key && echo "Done!" || echo "Not found."

    echo -n "Loading crypto configuration..." && load_sd_crypto_config && echo "Done!" || echo "Not found."

    if has_any_keys
    then
        set_key_index "`next_key_idx 256`"
    fi

    alsa_restore

    set_initialized
    echo "Initialized!"

    # Put a new seed onto the SD card. This call will block until the RNG is
    # initialized, so this needs to run in a background process (it is)
    echo -n "Saving new seed..." && save_sd_seed && echo "Done!" || echo "Error."

    # Only need the SD card image if the configuration menu is enabled
    # and this is not a Key Fill device
    if config_enabled && ! key_fill_only
    then
        echo -n "Creating SD card image..." && \
            copy_sd_to_img "$SD_IMG" &> /dev/null && \
            extract_img_p1 "$SD_IMG" "$SD_IMG_DOS" && \
            echo "Done!" || echo "Error."
    fi

    # Only need SSH keys if the configuration menu is enabled or
    # this is a Key Fill device
    if config_enabled || key_fill_only
    then
        /usr/bin/ssh-keygen -A
    fi
}

main | logger -t initialize -p daemon.info

# Common shell functions for use by other scripts

CRYPTO_INI_SYS=/etc/crypto.ini
CRYPTO_INI_USR=/etc/crypto.ini.sd
CRYPTO_INI_ALL=/etc/crypto.ini.all

ASOUND_CFG=/var/lib/alsa/asound.state
SEED_FILE=/var/run/random-seed
KEY_FILE=/etc/key

SD_DEV=/dev/mmcblk0p1

# Copies a text file to/from the SD card
alias mcopy_text="mcopy -t -n -D o -i $SD_DEV"
# Copies a binary file to/from the SD card
alias mcopy_bin="mcopy -D o -n -i $SD_DEV"

# Lists the sound devices in the system
alias aplay_ls="aplay -l"

# Loads the sound card config from the SD card
alias load_sd_sound_config="mcopy_text ::config/asound.state $ASOUND_CFG"

# Loads the crypto.ini file from the SD card
alias load_sd_crypto_config="cp $CRYPTO_INI_SYS $CRYPTO_INI_ALL && mcopy_text ::config/crypto.ini $CRYPTO_INI_USR && gen_combined_crypto_config"

# Loads the key from the SD card
alias load_sd_key="mcopy_bin ::config/key $KEY_FILE"

# Loads the shadow file from the SD card
alias load_sd_shadow="mcopy_text ::config/shadow /etc/shadow && chown root:root /etc/shadow && chmod 000 /etc/shadow"

# Seeds the RNG with random data from the SD card, if available
alias seed_rng_with_sd="mcopy_bin ::seed $SEED_FILE && dd if=$SEED_FILE of=/dev/urandom bs=512"

# Saves the sound card config to the SD card
alias save_sd_sound_config="mcopy_text $ASOUND_CFG ::config/asound.state"

# Saves the user crypto.ini file to the SD card
alias save_sd_crypto_config="mcopy_text "$CRYPTO_INI_USR" ::config/crypto.ini"

# Saves a new random seed with data from the RNG
alias save_sd_seed="dd if=/dev/random of=$SEED_FILE bs=512 count=1 && mcopy_bin $SEED_FILE ::seed"

# Saves the key to the SD card
alias save_sd_key="mcopy_bin $KEY_FILE ::config/key"

# Generates the crypto.ini.all from the user config and system config
alias gen_combined_crypto_config="cat $CRYPTO_INI_SYS $CRYPTO_INI_USR > $CRYPTO_INI_ALL"

# Generates a new key
alias gen_key="dd if=/dev/hwrng of=/dev/urandom bs=512 count=1 && dd if=/dev/random of=$KEY_FILE bs=131 count=1"

# Restores ALSA sound config for all sound cards
alias alsa_restore="aplay_ls | grep -o -E 'USB_[UL][LR]' | xargs restore.sh"

# Tests whether the configuration is "initialized" from the SD card
alias is_initialized="test -e /var/run/initialized"

# Takes a sound card name and strips off the "hw:"
# prefix if it is present
sound_strip_prefix()
{
    echo "$1" | sed -e 's/hw://g'
}

# Takes a sound card name or number and returns
# a zero exit code if the device is present and
# a non-zero exit code if the device isn't
sound_dev_active()
{
    NAME=`sound_strip_prefix "$1"`
    if echo "$NAME" | grep -q USB
    then
        aplay_ls | grep -q "$NAME"
    else
        aplay_ls | grep -q "card $NAME"
    fi
}

# Takes any number of sound card names or numbers
# and returns a zero exit code if they are all
# present and a non-zero exit code if they aren't
sound_dev_active_all()
{
    for NAME in "$@"
    do
        if ! sound_dev_active "$NAME"
        then
            return 1
        fi
    done

    return 0
}

# Takes a sound card name and outputs the card number
sound_dev_card_num()
{
    NAME=`sound_strip_prefix "$1"`
    aplay_ls | grep "$NAME" | grep -o -E "card \w" | cut -d ' ' -f 2
}

# Takes a jack server name and returns a 0
# exit code if it is inactive
jackd_inactive()
{
    jack_wait -s "$1" -c 2>/dev/null | grep -q "not running"
}

# Takes a jack server name and returns a 0
# exit code if it is running
jackd_active()
{
    ! jackd_inactive "$1"
}

# Takes any number of jack server names and
# returns a 0 exit code if any of them are
# running
jackd_active_any()
{
    for NAME in "$@"
    do
        if jackd_active "$NAME"
        then
            return 0
        fi
    done

    return 1
}

# Blocks until the /var/run/initialized file is
# present
wait_initialized()
{
    while ! is_initialized
    do
        inotifywait -qq -t 1 --include initialized -e create /var/run/
    done
}

# Blocks until the jack server with the specified name
# is running
wait_jackd()
{
    while jackd_inactive "$1"
    do
        sleep .1
    done
}

# Blocks until the SD card partition is available
wait_sd()
{
    while test ! -b "$SD_DEV"
    do
        inotifywait -qq -t 1 --include mmcblk0p1 -e create /dev/
    done
}

# Blocks until all sound cards are active
wait_sound_dev_active_all()
{
    while ! sound_dev_active_all "$@"
    do
        sleep .1
    done
}

# Gets a configuration value from either the user config file if present
# or the system one
get_config_val()
{
    iniget "$1" "$2" "$CRYPTO_INI_USR" "$CRYPTO_INI_SYS"
}

# Gets a configuration value from the user config file, if present
get_user_config_val()
{
    iniget "$1" "$2" "$CRYPTO_INI_USR"
}

# Gets a configuration value from the system config file
get_sys_config_val()
{
    iniget "$1" "$2" "$CRYPTO_INI_SYS"
}

# Saves a configuration value to the user config file
set_config_val()
{
    iniset "$1" "$2" "$3" "$CRYPTO_INI_USR" && gen_combined_crypto_config
}

# Takes a parameter "VoiceDevice" or "ModemDevice"
# and returns the configuration value for that setting
get_sound_hw_device()
{
    get_config_val JACK "$1"
}

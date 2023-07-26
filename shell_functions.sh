# Common shell functions for use by other scripts

CRYPTO_INI_SYS=/etc/crypto.ini
CRYPTO_INI_USR=/etc/crypto.ini.sd
CRYPTO_INI_ALL=/etc/crypto.ini.all

ASOUND_CFG=/var/lib/alsa/asound.state
SEED_FILE=/var/run/random-seed

TTS_FILE=/tmp/tts.wav
NOTIFY_FILE=/tmp/notify.wav

SD_DEV=/dev/mmcblk0p1

# Copies a text file to/from the SD card
alias mcopy_text="mcopy -t -n -D o -i $SD_DEV"
# Copies a binary file to/from the SD card
alias mcopy_bin="mcopy -D o -n -i $SD_DEV"
# Lists directories from the SD card
alias mdir_sd="mdir -i $SD_DEV"
# Deletes files from the SD card
alias mdel_sd="mdel -i $SD_DEV"

# Lists the sound devices in the system
alias aplay_ls="aplay -l"

# Loads the sound card config from the SD card
alias load_sd_sound_config="mcopy_text ::config/asound.state $ASOUND_CFG"

# Seeds the RNG with random data from the SD card, if available
alias seed_rng_with_sd="mcopy_bin ::seed $SEED_FILE && dd if=$SEED_FILE of=/dev/urandom bs=512"

# Saves the sound card config to the SD card
alias save_sd_sound_config="mcopy_text $ASOUND_CFG ::config/asound.state"

# Saves the user crypto.ini file to the SD card
alias save_sd_crypto_config="mcopy_text "$CRYPTO_INI_USR" ::config/crypto.ini"

# Saves a new random seed with data from the RNG
alias save_sd_seed="dd if=/dev/random of=$SEED_FILE bs=512 count=1 && mcopy_bin $SEED_FILE ::seed"

# Generates the crypto.ini.all from the user config and system config
alias gen_combined_crypto_config="cat $CRYPTO_INI_SYS $CRYPTO_INI_USR > $CRYPTO_INI_ALL"

# Restores ALSA sound config for all sound cards
alias alsa_restore="aplay_ls | grep -o -E 'USB_[UL][LR]' | xargs restore.sh"

# Tests whether the configuration is "initialized" from the SD card
alias is_initialized="test -e /var/run/initialized"

# Sets the "initialized" flag
alias set_initialized="touch /var/run/initialized"

# Tests whether the transmitter service is initialized
alias is_tx_initialized="test -e /var/run/tx_initialized"

# Tests whether the system has an SD card installed
alias has_sd_card="test -b $SD_DEV"

# Runs espeak with settings optimized for radio transmission
alias espeak_radio="espeak -v en -g 10 -s 140"

# Runs espeak with settings optimized for direct headset listening.
# The cadence is a bit faster since it isn't going through the radio
# CODEC
alias espeak_headset="espeak -v en -g 6 -s 160"

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
    if test -z "$1"
    then
        echo "usage: sound_dev_active <sound dev name>" >&2
        return 1
    fi

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
    if test -z "$1"
    then
        echo "usage: sound_dev_card_num <server name>" >&2
        return 1
    fi

    NAME=`sound_strip_prefix "$1"`
    aplay_ls | grep "$NAME" | grep -o -E "card \w" | cut -d ' ' -f 2
}

# Takes a jack server name and returns a 0
# exit code if it is inactive
jackd_inactive()
{
    if test -z "$1"
    then
        NAME="default"
    else
        NAME="$1"
    fi

    jack_wait -s "$NAME" -c 2>/dev/null | grep -q "not running"
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
    return 0
}

# Blocks until the jack server with the specified name
# is running
wait_jackd()
{
    while jackd_inactive "$1"
    do
        sleep .1
    done
    return 0
}

# Blocks until the SD card partition is available
wait_sd()
{
    while ! has_sd_card
    do
        inotifywait -qq -t 1 --include mmcblk0p1 -e create /dev/
    done
    return 0
}

# Blocks until all sound cards are active
wait_sound_dev_active_all()
{
    while ! sound_dev_active_all "$@"
    do
        sleep .1
    done
    return 0
}

# Gets a configuration value from either the user config file if present
# or the system one
get_config_val()
{
    if test -z "$1" || test -z "$2"
    then
        echo "usage: get_config_val <section> <key>" >&2
        return 1
    fi

    iniget "$1" "$2" "$CRYPTO_INI_USR" "$CRYPTO_INI_SYS"
}

# Gets a configuration value from the user config file, if present
get_user_config_val()
{
    if test -z "$1" || test -z "$2"
    then
        echo "usage: get_user_config_val <section> <key>" >&2
        return 1
    fi

    iniget "$1" "$2" "$CRYPTO_INI_USR"
}

# Gets a configuration value from the system config file
get_sys_config_val()
{
    if test -z "$1" || test -z "$2"
    then
        echo "usage: get_sys_config_val <section> <key>" >&2
        return 1
    fi

    iniget "$1" "$2" "$CRYPTO_INI_SYS"
}

# Saves a configuration value to the user config file
set_config_val()
{
    if test -z "$1" || test -z "$2"
    then
        echo "usage: set_config_val <section> <key> <value>" >&2
        return 1
    fi

    iniset "$1" "$2" "$3" "$CRYPTO_INI_USR" && gen_combined_crypto_config
}

# Takes a parameter "VoiceDevice" or "ModemDevice"
# and returns the configuration value for that setting
get_sound_hw_device()
{
    if test -z "$1"
    then
        echo "usage: get_sound_hw_device <key>" >&2
        return 1
    fi

    get_config_val JACK "$1"
}

# Copies the MBR and first partition on the SD card to the specified image file
copy_sd_to_img()
{
    if test -z "$1"
    then
        echo "usage: copy_sd_to_img <filepath>" >&2
        return 1
    fi

    BLOCK_SIZE=`fdisk -u -l /dev/mmcblk0 | grep -o -E '[0-9]+ bytes$' | cut -d ' ' -f 1`
    END_BLOCK=`fdisk -u -l /dev/mmcblk0 | grep "$SD_DEV" | xargs echo | cut -d ' ' -f 6`

    BLOCK_COUNT=$((END_BLOCK+1))
    TOTAL_BYTES=$((BLOCK_SIZE*BLOCK_COUNT))

    # Sanity check that this is a valid SD card (which has a 32MB partition
    # but we are being conservative here and saying no larger than 200MB)
    test "$TOTAL_BYTES" -lt 200000000 && dd if=/dev/mmcblk0 of="$1" bs="$BLOCK_SIZE" count="$BLOCK_COUNT" conv=fsync status=progress && echo "Success!" 1>&2
}

copy_img_to_sd()
{
    if test -z "$1"
    then
        echo "usage: copy_img_to_sd <filepath>" >&2
        return 1
    fi

    dd if="$1" of=/dev/mmcblk0 bs=512 conv=fsync status=progress && partprobe /dev/mmcblk0 && save_sd_seed && echo "Success" 1>&2
}

ensure_sd_has_config_dir()
{
    if ! mdir -i "$SD_DEV" -b | grep -q '::/config/'
    then
        mkdir /tmp/config && mcopy -i "$SD_DEV" /tmp/config :: && rmdir /tmp/config
    fi
}

# Loads the crypto.ini file from the SD card and
# attempts to make the config consistent in the event of failure
load_sd_crypto_config()
{
    # Success condition
    if mcopy_text ::config/crypto.ini "$CRYPTO_INI_USR" && gen_combined_crypto_config
    then
        return 0
    # Failed to copy file from SD card, user file did not already exist.
    # Just create a crypto.ini.all from the system one and return an error
    elif test ! -e "$CRYPTO_INI_USR"
    then
        cp "$CRYPTO_INI_SYS" "$CRYPTO_INI_ALL"
        return 1
    # Failed to copy file from SD card, user file already exists.
    # Generate a crypto.ini.all from the system one and the old
    # user one, but still return an error
    else
        gen_combined_crypto_config
        return 1
    fi
}

# echoes a key path for the specified Key Slot
# to stdout
get_key_path()
{
    KEY_PATH="/etc/key"
    if test "$1" -gt 1
    then
        KEY_PATH="/etc/key$1"
    fi

    echo "$KEY_PATH"
}

# Generates a new key and stores it to the specified Key Slot
gen_key()
{
    if test -z "$1"
    then
        KEY_PATH=`get_key_path 1`
    else
        KEY_PATH=`get_key_path "$1"`
    fi

    dd if=/dev/hwrng of=/dev/urandom bs=512 count=1 && \
        dd if=/dev/random of="$KEY_PATH" bs=131 count=1
}

# Tests whether or not a key is in a particular Key Slot
has_key()
{
    KEY_PATH=`get_key_path "$1"`
    test -f "$KEY_PATH"
}

# Loads the keys from the SD card
load_sd_key()
{
    if mcopy_bin ::config/key* /etc/
    then
        PI_KEYS=`mktemp`
        SD_KEYS=`mktemp`

        find /etc/ -name 'key*' | sed -e 's|/etc/||g' | sort > "$PI_KEYS"
        mdir_sd -b ::config/key* | sed -e 's|::/config/||g' | sort > "$SD_KEYS"

        comm -23 "$PI_KEYS" "$SD_KEYS" | sed -e 's|^|/etc/|' | xargs -r rm -f
        RET=$?

        rm -f "$PI_KEYS" "$SD_KEYS"
        return $RET
    fi
}

# Saves the keys to the SD card
save_sd_key()
{
    if mcopy_bin /etc/key* ::config/
    then
        PI_KEYS=`mktemp`
        SD_KEYS=`mktemp`
        find /etc/ -name 'key*' | sed -e 's|/etc/||g' | sort > "$PI_KEYS"
        mdir_sd -b ::config/key* | sed -e 's|::/config/||g' | sort > "$SD_KEYS"

        # Can't use mdel_sd in xargs
        comm -23 "$SD_KEYS" "$PI_KEYS" | sed -e 's|^|::config/|' | xargs -r mdel -i "$SD_DEV"
        RET=$?

        rm -f "$PI_KEYS" "$SD_KEYS"
        return $RET
    fi
}

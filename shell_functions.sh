# Common shell functions for use by other scripts
set -o pipefail

CRYPTO_INI_SYS=/etc/crypto.ini
CRYPTO_INI_USR=/etc/crypto.ini.sd
CRYPTO_INI_ALL=/etc/crypto.ini.all

ASOUND_CFG=/var/lib/alsa/asound.state
SEED_FILE=/var/run/random-seed

TTS_FILE=/tmp/tts.wav
NOTIFY_FILE=/tmp/notify.wav

SD_DEV=/dev/mmcblk0p1
SD_IMG=/tmp/sd.img
SD_IMG_DOS=/tmp/sd_dos.img

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

# Seeds the RNG with random data from the SD card, if available
alias seed_rng_with_sd="mcopy_bin ::seed $SEED_FILE && dd if=$SEED_FILE of=/dev/urandom bs=512"

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

# Saves a configuration value to the system config file
set_sys_config_val()
{
    if test -z "$1" || test -z "$2"
    then
        echo "usage: set_config_val <section> <key> <value>" >&2
        return 1
    fi

    iniset "$1" "$2" "$3" "$CRYPTO_INI_SYS" && gen_combined_crypto_config
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

# Extracts first partition from an SD card image
extract_img_p1()
{
    if test -z "$1" || test -z "$2"
    then
        echo "usage: extract_img_p1 <src_filepath> <dst_filepath>"
        return 1
    fi

    BLOCK_SIZE=`fdisk -u -l "$1" | grep -o -E '[0-9]+ bytes$' | cut -d ' ' -f 1`
    START_BLOCK=`fdisk -u -l "$1" | grep "${1}1" | xargs echo | cut -d ' ' -f 5`
    END_BLOCK=`fdisk -u -l "$1" | grep "${1}1" | xargs echo | cut -d ' ' -f 6`

    BLOCK_COUNT=$((END_BLOCK-START_BLOCK+1))
    dd if="$1" of="$2" bs="$BLOCK_SIZE" count="$BLOCK_COUNT" skip="$START_BLOCK"
}

combine_img_p1()
{
    if test -z "$1" || test -z "$2"
    then
        echo "usage: extract_img_p1 <img_filepath> <part_filepath>"
        return 1
    fi

    BLOCK_SIZE=`fdisk -u -l "$1" | grep -o -E '[0-9]+ bytes$' | cut -d ' ' -f 1`
    START_BLOCK=`fdisk -u -l "$1" | grep "${1}1" | xargs echo | cut -d ' ' -f 5`
    dd if="$2" of="$1" bs="$BLOCK_SIZE" seek="$START_BLOCK"
}

# Copies SD card image to SD card
copy_img_to_sd()
{
    if test -z "$1"
    then
        echo "usage: copy_img_to_sd <filepath>" >&2
        return 1
    fi

    dd if="$1" of=/dev/mmcblk0 bs=512 conv=fsync status=progress && \
        partprobe /dev/mmcblk0 && \
        echo "Success" 1>&2
}

ensure_sd_has_config_dir()
{
    if ! (mdir_sd -b | grep -q '::/config/')
    then
        mkdir -p /tmp/config && mcopy -i "$SD_DEV" /tmp/config :: && rmdir /tmp/config
    fi
}

# Loads the sound card config from the SD card. The
# SD card is treated as authoritative, meaning that
# if no config file is on the SD card the local one
# is deleted
load_sd_sound_config()
{
    if has_sd_card
    then
        if mcopy_text ::config/asound.state "$ASOUND_CFG"
        then
            return 0
        else
            # Failed to copy file from SD card, meaning it must not exist
            rm -f "$ASOUND_CFG"
            return 0
        fi
    else
        return 1
    fi
}

# Saves the sound card config to the SD card. The
# local file is treated as authoritative, meaning that
# if there is no local config file any one on the SD
# card is deleted
save_sd_sound_config()
{
    if has_sd_card
    then
        if test -f "$ASOUND_CFG"
        then
            mcopy_text $ASOUND_CFG ::config/asound.state
        elif mdir_sd -b ::config/asound.state
        then
            mdel_sd ::config/asound.state
        else
            return 0
        fi
    else
        reutrn 1
    fi
}

# Loads the crypto.ini file from the SD card. The
# SD card is treated as authoritative, meaning that
# if no config file is on the SD card the local one
# is deleted
load_sd_crypto_config()
{
    if has_sd_card
    then
        # Success condition
        if mcopy_text ::config/crypto.ini "$CRYPTO_INI_USR" && gen_combined_crypto_config
        then
            return 0
        # Failed to copy file from SD card, meaning it must not exist.
        # Delete the local copy
        else
            rm -f "$CRYPTO_INI_USR"
            cp "$CRYPTO_INI_SYS" "$CRYPTO_INI_ALL"
            return 0
        fi
    else
        return 1
    fi
}

# Saves the user crypto.ini file to the SD card. The local
# file is treated as authoritative, meaning that if there is
# no local user config file any one on the SD card is deleted
save_sd_crypto_config()
{
    if has_sd_card
    then
        if test -f "$CRYPTO_INI_USR"
        then
            mcopy_text "$CRYPTO_INI_USR" ::config/crypto.ini
        elif mdir_sd -b ::config/crypto.ini
        then
            mdel_sd ::config/crypto.ini
        else
            return 0;
        fi
    else
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

sd_has_any_keys()
{
    mdir_sd -b ::config/key*
}

has_any_keys()
{
    test `find /etc -type f -name 'key*' | wc -l` -gt 0
}

# Loads keys from the SD card if and only if
# 1. There are no local keys
# 2. There is at least one key on the SD card
load_sd_key_noclobber()
{
    if ! has_any_keys && sd_has_any_keys
    then
        mcopy_bin ::config/key* /etc/
    else
        return 1
    fi
}

# Loads the keys from the SD card
load_sd_key()
{
    MDIR_OUT=`mktemp`
    # We want this to succeed if the SD card is inserted but no keys are found
    # and fail if there is no SD card. So don't wildcard on the mdir call but
    # instead pass it through grep
    if mdir_sd -b ::config/ > "$MDIR_OUT"
    then
        SD_KEYS=`mktemp`

        grep key < "$MDIR_OUT" | sed -e 's|::/config/||g' | sort > "$SD_KEYS"
        NUM_KEYS=`wc -l < "$SD_KEYS"`

        if test "$NUM_KEYS" -eq 0 || mcopy_bin ::config/key* /etc/
        then
            PI_KEYS=`mktemp`

            find /etc/ -type f -name 'key*' | sed -e 's|/etc/||g' | sort > "$PI_KEYS"

            comm -23 "$PI_KEYS" "$SD_KEYS" | sed -e 's|^|/etc/|' | xargs -r rm -f
            RET=$?

            rm -f "$PI_KEYS" "$SD_KEYS" "$MDIR_OUT"
            return $RET
        else
            rm -f "$SD_KEYS" "$MDIR_OUT"
            return 1
        fi
    else
        rm -f "$MDIR_OUT"
        return 1
    fi
}

# Saves the keys to the SD card
save_sd_key()
{
    PI_KEYS=`mktemp`
    if find /etc/ -type f -name 'key*' | sed -e 's|/etc/||g' | sort > "$PI_KEYS"
    then
        NUM_KEYS=`wc -l < $PI_KEYS`
        if test "$NUM_KEYS" -eq 0 || mcopy_bin /etc/key* ::config/
        then
            SD_KEYS=`mktemp`
            mdir_sd -b ::config/key* | sed -e 's|::/config/||g' | sort > "$SD_KEYS"

            # Can't use mdel_sd in xargs
            comm -23 "$SD_KEYS" "$PI_KEYS" | sed -e 's|^|::config/|' | xargs -r mdel -i "$SD_DEV"
            RET=$?

            rm -f "$PI_KEYS" "$SD_KEYS"
            return $RET
        else
            rm -f "$PI_KEYS"
            return 1
        fi
    else
        rm -f "$PI_KEYS"
        return 1
    fi
}

next_key_idx()
{
    NEXT_KEY_IDX=$(($1+1))
    # Prevent infinite loop if no key
    while test "$NEXT_KEY_IDX" -ne "$1" && ! has_key "$NEXT_KEY_IDX"
    do
        if test "$NEXT_KEY_IDX" -ge 256
        then
            NEXT_KEY_IDX=1
        else
            NEXT_KEY_IDX=$((NEXT_KEY_IDX+1))
        fi
    done

    echo "$NEXT_KEY_IDX"
}

headset_tts()
{
    espeak_headset -w "$NOTIFY_FILE" "$@" &> /dev/null && \
        /etc/init.d/S31jack_crypto_rx signal SIGUSR1
}

execute_alert_broadcast()
{
     espeak_radio -w "$TTS_FILE" "$@" &> /dev/null && \
        /etc/init.d/S30jack_crypto_tx signal SIGUSR1 && \
        headset_tts "$@"
}

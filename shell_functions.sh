# Common shell functions for use by other scripts
set -o pipefail

VERSION="0.14.0"

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

USB_DEV=/dev/sda1

BLACK_KEY_DIR=/etc/black/keys
DKEK_DIR=/etc/black/dkeks
CIK_DIR=/etc/ciks

# Copies a text file
alias mcopy_text="mcopy -t -n -D o"
# Copies a text file to/from the SD card
alias mcopy_text_sd="mcopy_text -i $SD_DEV"
# Copies a binary file
alias mcopy_bin="mcopy -D o -n"
# Copies a binary file to/from the SD card
alias mcopy_bin_sd="mcopy_bin -i $SD_DEV"
# Copies a binary file to/from the USB drive
alias mcopy_bin_usb="mcopy_bin -i $USB_DEV"
# Lists directories from the SD card
alias mdir_sd="mdir -i $SD_DEV"
# Lists directories from the USB drive
alias mdir_usb="mdir -i $USB_DEV"
# Deletes files from the SD card
alias mdel_sd="mdel -i $SD_DEV"

# Lists the sound devices in the system
alias aplay_ls="aplay -l"

# Seeds the RNG with random data from the SD card, if available
alias seed_rng_with_sd="mcopy_bin_sd ::seed $SEED_FILE && dd if=$SEED_FILE of=/dev/urandom bs=512"

# Saves a new random seed with data from the RNG
alias save_sd_seed="dd if=/dev/random of=$SEED_FILE bs=512 count=1 && mcopy_bin_sd $SEED_FILE ::seed"

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
alias has_sd_card="test -b /dev/mmcblk0"

# Tests whether the system has a USB flash drive installed
alias has_usb_drive="test -b /dev/sda"

# Runs espeak with settings optimized for radio transmission
alias espeak_radio="espeak -v en -g 10 -s 140"

# Runs espeak with settings optimized for direct headset listening.
# The cadence is a bit faster since it isn't going through the radio
# CODEC
alias espeak_headset="espeak -v en -g 6 -s 160"

# Gets the current Key Index
alias get_key_index="get_sys_config_val Crypto KeyIndex"

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
    START_BLOCK=`fdisk -u -l "$1" | grep -E "^${1}" | head -n 1 | xargs echo | cut -d ' ' -f 5`
    END_BLOCK=`fdisk -u -l "$1" | grep -E "^${1}" | head -n 1 | xargs echo | cut -d ' ' -f 6`

    BLOCK_COUNT=$((END_BLOCK-START_BLOCK+1))
    dd if="$1" of="$2" bs="$BLOCK_SIZE" count="$BLOCK_COUNT" skip="$START_BLOCK" conv=fsync
}

combine_img_p1()
{
    if test -z "$1" || test -z "$2"
    then
        echo "usage: combine_img_p1 <img_filepath> <part_filepath>"
        return 1
    fi

    BLOCK_SIZE=`fdisk -u -l "$1" | grep -o -E '[0-9]+ bytes$' | cut -d ' ' -f 1`
    START_BLOCK=`fdisk -u -l "$1" | grep -E "^${1}" | head -n 1 | xargs echo | cut -d ' ' -f 5`
    dd if="$2" of="$1" bs="$BLOCK_SIZE" seek="$START_BLOCK" conv=fsync
}

# Copies SD card image to SD card
copy_img_to_sd()
{
    if test -z "$1"
    then
        echo "usage: copy_img_to_sd <filepath>" >&2
        return 1
    fi

    if test -n "$2"
    then
        DST_DEV="$2"
    else
        DST_DEV="/dev/mmcblk0"
    fi

    SRC_SIZE=`stat -c '%s' "$1"`
    SRC_BLOCKS=$(((SRC_SIZE+511)/512))
    VER_FILE=`mktemp`

    echo "Copying" 1>&2 && \
        dd if="$1" of="$DST_DEV" bs=1MiB conv=fsync oflag=direct,sync status=progress && sync && \
        echo "Verifying" 1>&2 && \
        dd if="$DST_DEV" of="$VER_FILE" bs=512 count="$SRC_BLOCKS" status=progress && \
        diff "$VER_FILE" "$1" && \
        partprobe "$DST_DEV" && \
        echo "Success" 1>&2
    RET="$?"

    rm -f "$VER_FILE"

    return "$RET"
}

ensure_sd_has_config_dir()
{
    if test -z "$1"
    then
        SD_DST="$SD_DEV"
    else
        SD_DST="$1"
    fi

    if ! mdir -i "$SD_DST" -b '::config' &> /dev/null
    then
        if mkdir -p /tmp/config && mcopy -i "$SD_DST" /tmp/config ::
        then
            rmdir /tmp/config
            return 0
        else
            rmdir /tmp/config
            return 1
        fi
    else
        return 0
    fi
}

ensure_sd_has_black_keys_dir()
{
    if test -z "$1"
    then
        SD_DST="$SD_DEV"
    else
        SD_DST="$1"
    fi

    if ! mdir -i "$SD_DST" -b '::black_keys' &> /dev/null
    then
        if mkdir -p /tmp/black_keys && mcopy -i "$SD_DST" /tmp/black_keys ::
        then
            rmdir /tmp/black_keys
            return 0
        else
            rmdir /tmp/black_keys
            return 1
        fi
    else
        return 0
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
        if mcopy_text_sd ::config/asound.state "$ASOUND_CFG"
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
            mcopy_text_sd "$ASOUND_CFG" ::config/asound.state
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
        if mcopy_text_sd ::config/crypto.ini "$CRYPTO_INI_USR" && gen_combined_crypto_config
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
            mcopy_text_sd "$CRYPTO_INI_USR" ::config/crypto.ini
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

# echoes a red key path for the specified Key Slot
# to stdout
get_red_key_path()
{
    KEY_PATH="/etc/keys/key"
    if test "$1" -gt 1
    then
        KEY_PATH="/etc/keys/key$1"
    fi

    echo "$KEY_PATH"
}

# Returns the file paths of all black keys in the
# specified Key Slot
get_all_black_key_paths()
{
    KEY_NAME="key"
    if test "$1" -gt 1
    then
        KEY_NAME="${KEY_NAME}$1"
    fi

    find "$BLACK_KEY_DIR" -type f -name "*.$KEY_NAME"
}

# echoes a black key path for the specified Key Slot
# and Device Serial to stdout
get_black_key_path()
{
    KEY_PATH="${BLACK_KEY_DIR}/${2}.key"
    if test "$1" -gt 1
    then
        KEY_PATH="${KEY_PATH}${1}"
    fi

    echo "$KEY_PATH"
}

# Returns the file paths of all red and black keys
# in the specified Key Slot
get_all_key_paths()
{
    get_red_key_path "$1"
    get_all_black_key_paths "$1"
}

# $1 Key Encryption Key Path
# $2 Red Key Path
encrypt_key()
{
    DEVICE_SERIAL=`echo "$1" | sed -e "s|${DKEK_DIR}/||g" -e 's|.kek||g'`
    BLK_KEY_PATH=`echo "$2" | sed -e "s|/etc/keys/|${BLACK_KEY_DIR}/${DEVICE_SERIAL}.|g"`
    if ! test -f "$BLK_KEY_PATH"
    then
        TMP_BLK_KEY=`mktemp`
        openssl pkeyutl -encrypt -pubin -inkey "$1" -in "$2" -out "$TMP_BLK_KEY" && \
            install -m 0644 "$TMP_BLK_KEY" "$BLK_KEY_PATH"
        RET=$?
        rm -f "$TMP_BLK_KEY"
        return "$RET"
    else
        return 0
    fi
}

encrypt_all()
{
    for RED_KEY in `get_all_red_keys`
    do
        for DKEK in `get_all_dkeks`
        do
            encrypt_key "$DKEK" "$RED_KEY"
        done
    done

    return 0
}

# Generates a new key and stores it to the specified Key Slot
gen_key()
{
    if test -z "$1"
    then
        KEY_PATH=`get_red_key_path 1`
    else
        KEY_PATH=`get_red_key_path "$1"`
    fi

    if dd if=/dev/hwrng of=/dev/urandom bs=512 count=1 && \
       dd if=/dev/random of="$KEY_PATH" bs=131 count=1
    then
        get_all_black_key_paths "$1" | xargs rm -f
        for KEK in `get_all_dkeks`
        do
            encrypt_key "$KEK" "$KEY_PATH"
        done
    fi
}

# Tests whether or not a red key is in a particular Key Slot
has_red_key()
{
    KEY_PATH=`get_red_key_path "$1"`
    test -f "$KEY_PATH"
}

# Tests whether or not a black key is in a particular Key Slot
has_black_key()
{
    test "`get_all_black_key_paths "$1" | wc -l`" -gt 0
}

sd_has_any_keys()
{
    if device_kdk_encrypted
    then
        mdir_sd -b ::config/key* &> /dev/null || \
            mdir_sd -b ::black_keys/*.key* &> /dev/null || \
            mdir_sd -b ::cik &> /dev/null
    else
        mdir_sd -b ::config/key* &> /dev/null || \
            mdir_sd -b ::black_keys/*.key* &> /dev/null
    fi
}

usb_has_any_keys()
{
    if device_kdk_encrypted
    then
        mdir_usb -b ::config/key* &> /dev/null || \
            mdir_usb -b ::black_keys/*.key* &> /dev/null || \
            mdir_usb -b ::cik &> /dev/null
    else
        mdir_usb -b ::config/key* &> /dev/null || \
            mdir_usb -b ::black_keys/*.key* &> /dev/null
    fi
}

ext_has_any_keys()
{
    sd_has_any_keys || usb_has_any_keys || ethernet_link_detected
}

has_any_red_keys()
{
    test "`get_all_red_keys | wc -l`" -gt 0
}

has_any_black_keys()
{
    test "`find "$BLACK_KEY_DIR" -type f -name '*.key*' | wc -l`" -gt 0
}

has_any_keys()
{
    has_any_red_keys || has_any_black_keys
}

get_all_dkeks()
{
    find "$DKEK_DIR" -type f -name '*.kek'
}

get_all_red_keys()
{
    find /etc/keys -type f -name 'key*'
}

has_any_dkeks()
{
    test "`get_all_dkeks | wc -l`" -gt 0
}

sd_has_any_dkeks()
{
    mdir_sd -b ::config/*.kek &> /dev/null
}

usb_has_any_dkeks()
{
    mdir_usb -b ::config/*.kek &> /dev/null
}

ext_has_any_dkeks()
{
    sd_has_any_dkeks || usb_has_any_dkeks || ethernet_link_detected
}

set_key_index()
{
    if test -z "$1"
    then
        echo "usage: set_key_index <index>" >&2
        return 1
    fi

    set_sys_config_val Crypto KeyIndex "$1"
}

# Loads keys from an external device if and only if
# 1. There are no local keys
# 2. There is at least one key on the SD card (first) or USB drive (second)
#    or ethernet is connected (third)
load_ext_key_noclobber()
{
    if sd_has_any_keys
    then
        if ! has_any_keys
        then
            if mcopy_bin_sd ::black_keys/*.key* "$BLACK_KEY_DIR" &> /dev/null
            then
                decrypt_black_keys
            elif mcopy_bin_sd ::config/key* /etc/keys/ &> /dev/null
            then
                encrypt_all
                # The keys will be unusable until the Crypto Ignition Key is
                # loaded, at which point it will be able to decrypt them
                if device_kdk_encrypted
                then
                    rm -f /etc/keys/key*
                fi
            elif device_kdk_encrypted && mcopy_bin_sd ::cik /tmp/ &> /dev/null
            then
                decrypt_kdk /tmp/cik && decrypt_black_keys
            else
                return 1
            fi
        elif device_kdk_encrypted && mcopy_bin_sd ::cik /tmp/ &> /dev/null
        then
            decrypt_kdk /tmp/cik && decrypt_black_keys
        else
            return 1
        fi
    elif usb_has_any_keys
    then
        if ! has_any_keys
        then
            if mcopy_bin_usb ::black_keys/*.key* "$BLACK_KEY_DIR" &> /dev/null
            then
                decrypt_black_keys
            elif mcopy_bin_usb ::config/key* /etc/keys/ &> /dev/null
            then
                encrypt_all
                # The keys will be unusable until the Crypto Ignition Key is
                # loaded, at which point it will be able to decrypt them
                if device_kdk_encrypted
                then
                    rm -f /etc/keys/key*
                fi
            elif device_kdk_encrypted && mcopy_bin_usb ::cik /tmp/ &> /dev/null
            then
                decrypt_kdk /tmp/cik && decrypt_black_keys
            else
                return 1
            fi
        elif device_kdk_encrypted && mcopy_bin_usb ::cik /tmp/ &> /dev/null
        then
            decrypt_kdk /tmp/cik && decrypt_black_keys
        else
            return 1
        fi
    elif ! has_any_keys && pppoe_link_established
    then
        if echo "get keys/*.key* $BLACK_KEY_DIR" | sftp -b - keyfill@10.0.0.1 &> /dev/null
        then
            decrypt_black_keys
        fi
    else
        return 1
    fi
}

# Loads key encryption keys from any external device with them
load_ext_dkek()
{
    LOADED=0
    if sd_has_any_dkeks && mcopy_bin_sd ::config/*.kek "$DKEK_DIR"
    then
         LOADED=1
    fi
    if usb_has_any_dkeks && mcopy_bin_usb ::config/*.kek "$DKEK_DIR"
    then
         LOADED=1
    fi
    if pppoe_link_established
    then
        if echo "get dkeks/*.kek $DKEK_DIR" | sftp -b - keyfill@10.0.0.1 &> /dev/null
        then
            LOADED=1
        fi
    fi

    test "$LOADED" -ne 0 && encrypt_all
}

# Loads device key encryption keys from the SD card
load_sd_dkek()
{
    MDIR_OUT=`mktemp`
    # We want this to succeed if the SD card is inserted but no keys are found
    # and fail if there is no SD card. So don't wildcard on the mdir call but
    # instead pass it through grep
    if mdir_sd -b ::config/ > "$MDIR_OUT"
    then
        SD_KEYS=`mktemp`

        grep kek < "$MDIR_OUT" | sed -e 's|::/config/||g' | sort > "$SD_KEYS"
        NUM_KEYS=`wc -l < "$SD_KEYS"`

        if test "$NUM_KEYS" -eq 0 || mcopy_bin_sd ::config/*.kek "$DKEK_DIR"
        then
            PI_KEYS=`mktemp`

            get_all_dkeks | sed -e "s|${DKEK_DIR}/||g" | sort > "$PI_KEYS"

            comm -23 "$PI_KEYS" "$SD_KEYS" | sed -e "s|^|${DKEK_DIR}/|" | xargs -r rm -f
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

# Loads the red keys from the SD card
load_sd_red_key()
{
    # We want this to succeed if the SD card is inserted but no keys are found
    # and fail if there is no SD card. So don't wildcard on the mdir call
    if mdir_sd -b ::config/key* &> /dev/null
    then
        mcopy_bin_sd ::config/key* /etc/keys/ &> /dev/null
    else
        return 1
    fi
}

# Loads the black keys from the SD card
load_sd_black_key()
{
    if mdir_sd -b ::black_keys/*.key* &> /dev/null
    then
        mcopy_bin_sd ::black_keys/*.key* "$BLACK_KEY_DIR" &> /dev/null
    else
        return 1
    fi
}

# Loads red and black keys from the SD card
load_sd_key()
{
    if load_sd_black_key
    then
        decrypt_black_keys
    else
        load_sd_red_key && encrypt_all
    fi
}

decrypt_black_keys()
{
    DEVICE_SERIAL=`get_device_serial`
    KDK=`get_device_kdk`
    if test -n "$KDK"
    then
        for BLK_KEY_PATH in "${BLACK_KEY_DIR}/${DEVICE_SERIAL}".key*
        do
            RED_KEY_PATH=/etc/keys/`echo "$BLK_KEY_PATH" | sed -e "s|${BLACK_KEY_DIR}/[0-9a-z-]\+\.||g"`
            TMP_RED_KEY=`mktemp`
            openssl pkeyutl -decrypt -inkey "$KDK" -in "$BLK_KEY_PATH" -out "$TMP_RED_KEY" && \
                mv "$TMP_RED_KEY" "$RED_KEY_PATH" || rm -f "$TMP_RED_KEY"
        done
        return 0
    else
        return 0
    fi
}

decrypt_kdk()
{
    ENCRYPTED_KDK=`get_encrypted_kdk`
    TMP_DECRYPTED_KDK=`mktemp`
    DECRYPTED_KDK=`echo "$ENCRYPTED_KDK" | sed -e 's|\.enc||g'`

    if openssl pkcs8 -scrypt -in "$ENCRYPTED_KDK" -out "$TMP_DECRYPTED_KDK" -passin "file:$1" && \
       mv "$TMP_DECRYPTED_KDK" "$DECRYPTED_KDK"
    then
        rm -f /etc/*.kdk.enc "$1"
        return 0
    else
        rm -f "$TMP_DECRYPTED_KDK" "$1"
        return 1
    fi
}

load_sd_dkdk()
{
    if mdir_sd ::config/*.kdk.enc &> /dev/null
    then
        mcopy_bin_sd ::config/*.kdk.enc /etc/
    else
        mcopy_bin_sd ::config/*.kdk /etc/
    fi
}

# Saves device key encryption keys to the SD card
save_sd_dkek()
{
    PI_KEYS=`mktemp`
    if get_all_dkeks | sed -e "s|${DKEK_DIR}/||g" | sort > "$PI_KEYS"
    then
        NUM_KEYS=`wc -l < $PI_KEYS`
        if test "$NUM_KEYS" -eq 0 || mcopy_bin_sd "$DKEK_DIR"/*.kek ::config/
        then
            SD_KEYS=`mktemp`
            mdir_sd -b ::config/*.kek | sed -e 's|::/config/||g' | sort > "$SD_KEYS"

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
    while test "$NEXT_KEY_IDX" -ne "$1" && ! has_red_key "$NEXT_KEY_IDX"
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

ethernet_link_detected()
{
    ethtool eth0 | grep -q 'Link detected: yes'
}

pppoe_link_established()
{
    ping -c 1 10.0.0.1 &> /dev/null
}

config_enabled()
{
    test "`get_config_val Config ConfigPassword`" != '*'
}

key_fill_only()
{
    test "`get_config_val Config KeyFillOnly`" -ne 0
}

device_kdk_encrypted()
{
    test "`get_encrypted_kdk | wc -l`" -gt 0
}

get_encrypted_kdk()
{
    find /etc/ -name '*.kdk.enc' | head -n 1
}

get_device_kdk()
{
    find /etc/ -name '*.kdk' | head -n 1
}

has_device_kdk()
{
    test "`get_device_kdk | wc -l`" -gt 0
}

get_device_serial()
{
    find /etc/ -name '*.kdk*' | head -n 1 | sed -e 's|/etc/||g' -e 's|\.kdk||g' -e 's|\.enc||g'
}

disable_keyfill()
{
    /etc/init.d/manual/S50sshd stop &> /dev/null
    /etc/init.d/manual/S10pppoe_server stop &> /dev/null
    ifconfig eth0 down &> /dev/null
    /etc/init.d/manual/S60keyfill_led stop &> /dev/null
}

enable_keyfill()
{
    ifconfig eth0 up &> /dev/null
    /etc/init.d/manual/S10pppoe_server start &> /dev/null
    /etc/init.d/manual/S50sshd start &> /dev/null
    /etc/init.d/manual/S60keyfill_led start &> /dev/null
}

toggle_keyfill()
{
    if /etc/init.d/manual/S10pppoe_server running
    then
        disable_keyfill
    else
        enable_keyfill
    fi
}

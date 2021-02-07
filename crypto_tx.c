/*---------------------------------------------------------------------------*\

  Originally derived from freedv_tx with modifications

\*---------------------------------------------------------------------------*/

/*

  This program is free software; you can redistribute it and/or modify
  it under the terms of the GNU Lesser General Public License version 2.1, as
  published by the Free Software Foundation.  This program is
  distributed in the hope that it will be useful, but WITHOUT ANY
  WARRANTY; without even the implied warranty of MERCHANTABILITY or
  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public
  License for more details.

  You should have received a copy of the GNU Lesser General Public License
  along with this program; if not, see <http://www.gnu.org/licenses/>.
*/

#include <assert.h>
#include <stdlib.h>
#include <stdio.h>
#include <stdint.h>
#include <string.h>
#include <errno.h>
#include <math.h>
#include <signal.h>
#include <sys/wait.h>
#include <unistd.h>

#include "freedv_api.h"
#include "crypto_cfg.h"
#include "crypto_log.h"

#ifndef TEMP_FAILURE_RETRY
#define TEMP_FAILURE_RETRY(expression) {int result; do result = (int)(expression); while (result == -1 && errno == EINTR); result;}
#endif

static volatile sig_atomic_t reload_config = 0;

static short rms(short vals[], int len) {
    if (len > 0) {
        int64_t total = 0;
        for (int i = 0; i < len; ++i) {
            int64_t val = vals[i];
            total += val * val;
        }

        return (short)sqrt(total / len);
    }
    else {
        return 0;
    }
}

static size_t read_input_file(short* buffer, size_t buffer_elems, FILE* file)
{
    size_t elems_read = 0;
    do {
        elems_read += fread(buffer + elems_read,
                            sizeof(short),
                            buffer_elems - elems_read,
                            file);

    }
    while (elems_read < buffer_elems && !feof(file) && !ferror(file));

    return elems_read;
}

static void handle_sighup(int sig) {
    reload_config = 1;
}

static void try_system_async(const char* cmd) {
    int stat = 0;
    TEMP_FAILURE_RETRY(wait(&stat));

    if (cmd != NULL && cmd[0] != '\0') {
        if (fork() == 0) {
            execl("/bin/sh", "/bin/sh", "-c", cmd, NULL);
        }
    }
}

int main(int argc, char *argv[]) {
    struct config *old = NULL;
    struct config *cur = NULL;

    FILE          *fin = NULL;
    FILE          *fout = NULL;
    FILE          *urandom = NULL;

    struct freedv *freedv = NULL;
    int            i;

    unsigned char  key[FREEDV_MASTER_KEY_LENGTH];
    unsigned char  iv[16];

    if (argc < 2) {
        fprintf(stderr, "usage: %s ConfigFile\n", argv[0]);
        exit(1);
    }

    signal(SIGHUP, handle_sighup);

    cur = calloc(1, sizeof(struct config));
    read_config(argv[1], cur);

    crypto_log logger = create_logger(cur->log_file, cur->log_level);

    open_input_file(old, cur, &fin);
    if (fin == NULL) {
        log_message(logger,
                    LOG_ERROR,
                    "Could not open input voice stream: %s",
                    cur->source_file);
        exit(1);
    }

    open_output_file(old, cur, &fout);
    if (fout == NULL) {
        log_message(logger,
                    LOG_ERROR,
                    "Could not open output data stream: %s",
                    cur->dest_file);
        exit(1);
    }

    open_iv_file(old, cur, &urandom);
    if (urandom == NULL) {
        log_message(logger,
                    LOG_ERROR,
                    "Unable to open random number generator: %s",
                    cur->random_file);
        exit(1);
    }

    if (fread(iv, 1, sizeof(iv), urandom) != sizeof(iv)) {
        log_message(logger, LOG_WARN, "Did not fully read initialization vector");
    }

    size_t key_bytes_read = read_key_file(cur->key_file, key);
    if (str_has_value(cur->key_file) && key_bytes_read != FREEDV_MASTER_KEY_LENGTH) {
        log_message(logger,
                    LOG_WARN,
                    "Truncated encryption key: Only %d bytes of a possible %d",
                    (int)key_bytes_read,
                    (int)FREEDV_MASTER_KEY_LENGTH);
    }

    freedv = freedv_open(FREEDV_MODE_2400B);
    if (freedv == NULL) {
        log_message(logger, LOG_ERROR, "Could not initialize voice modulator");
        exit(1);
    }

    if (str_has_value(cur->key_file)) {
        freedv_set_crypto(freedv, key, iv);
    }
    else {
        log_message(logger, LOG_WARN, "Encryption disabled");
    }

    /* handy functions to set buffer sizes, note tx/modulator always
       returns freedv_get_n_nom_modem_samples() (unlike rx side) */
    int n_speech_samples = freedv_get_n_speech_samples(freedv);
    short speech_in[n_speech_samples];
    int n_nom_modem_samples = freedv_get_n_nom_modem_samples(freedv);
    short mod_out[n_nom_modem_samples];

    unsigned short silent_frames = 0;
    /* OK main loop  --------------------------------------- */
    while(read_input_file(speech_in, n_speech_samples, fin) == n_speech_samples) {
        if (str_has_value(cur->key_file) && cur->vox_low > 0 && cur->vox_high > 0) {
            short rms_val = rms(speech_in, n_speech_samples);
            log_message(logger, LOG_DEBUG, "Voice RMS: %d", (int)rms_val);

            int reset_iv = 0;

            if (rms_val > cur->vox_high && silent_frames > 0) {
                log_message(logger,
                            LOG_INFO,
                            "Voice detected. RMS: %d",
                            (int)rms_val);
                silent_frames = 0;
            }
            /* If a frame drops below iv_low or is between iv_low and iv_high after
               dropping below iv_low, increment the silent counter */
            else if (rms_val < cur->vox_low || silent_frames > 0) {
                ++silent_frames;
                log_message(logger,
                            LOG_DEBUG,
                            "Quiet frame. Count: %d",
                            (int)silent_frames);

                if (cur->vox_period > 0 &&
                    (silent_frames == (25 * cur->vox_period))) {
                    log_message(logger,
                                LOG_INFO,
                                "New initialization vector at end of voice. RMS: %d",
                                (int)rms_val);
                    reset_iv = 1;
                }

                /* Reset IV every minute of silence (if configured)*/
                if (cur->silent_period > 0 &&
                    (silent_frames % (25 * cur->silent_period)) == 0) {
                    log_message(logger,
                                LOG_INFO,
                                "New initialization vector during long silence. RMS: %d",
                                (int)rms_val);
                    reset_iv = 1;
                }
            }

            if (reset_iv) {
                if (fread(iv, 1, sizeof(iv), urandom) != sizeof(iv)) {
                    log_message(logger,
                                LOG_WARN,
                                "Did not fully read initialization vector");
                }

                freedv_set_crypto(freedv, NULL, iv);
                try_system_async(cur->vox_cmd);
            }
        }

        freedv_tx(freedv, mod_out, speech_in);
        fwrite(mod_out, sizeof(short), n_nom_modem_samples, fout);

        if (reload_config != 0) {
            log_message(logger, LOG_NOTICE, "Reloading transmitter config");

            reload_config = 0;

            swap_config(&old, &cur);
            if (cur == NULL) {
                cur = calloc(1, sizeof(struct config));
            }
            read_config(argv[1], cur);

            if (strcmp(old->log_file, cur->log_file) != 0) {
                destroy_logger(logger);
                logger = create_logger(cur->log_file, cur->log_level);
            }

            logger.level = cur->log_level;

            open_input_file(old, cur, &fin);
            if (fin == NULL) {
                log_message(logger,
                            LOG_ERROR,
                            "Could not open input voice stream: %s",
                            cur->source_file);
                exit(1);
            }

            open_output_file(old, cur, &fout);
            if (fout == NULL) {
                log_message(logger,
                            LOG_ERROR,
                            "Could not open output data stream: %s",
                            cur->dest_file);
                exit(1);
            }

            open_iv_file(old, cur, &urandom);
            if (urandom == NULL) {
                log_message(logger,
                            LOG_ERROR,
                            "Unable to open random number generator: %s",
                            cur->random_file);
                exit(1);
            }

            if (fread(iv, 1, sizeof(iv), urandom) != sizeof(iv)) {
                log_message(logger,
                            LOG_WARN,
                            "Did not fully read initialization vector");
            }

            key_bytes_read = read_key_file(cur->key_file, key);
            if (str_has_value(cur->key_file) && key_bytes_read != FREEDV_MASTER_KEY_LENGTH) {
                log_message(logger,
                            LOG_WARN,
                            "Truncated encryption key: Only %d bytes of a possible %d",
                            (int)key_bytes_read,
                            (int)FREEDV_MASTER_KEY_LENGTH);
            }

            if (str_has_value(cur->key_file)) {
                freedv_set_crypto(freedv, key, iv);
            }
            else {
                log_message(logger, LOG_WARN, "Encryption disabled");
                freedv_set_crypto(freedv, NULL, NULL);
            }
        }
    }
    
    freedv_close(freedv);
    fclose(urandom);
    fclose(fin);
    fclose(fout);

    if (old != NULL) free(old);
    if (cur != NULL) free(cur);
    
    return 0;
}


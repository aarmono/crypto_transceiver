/*---------------------------------------------------------------------------*\

  Originally derived from freedv_rx with modifications

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
#include <limits.h>
#include <stdio.h>
#include <string.h>
#include <errno.h>
#include <stdlib.h>
#include <stdio.h>
#include <signal.h>
#include <math.h>

#include "freedv_api.h"
#include "crypto_cfg.h"
#include "crypto_log.h"

static volatile sig_atomic_t reload_config = 0;
static const unsigned short FRAMES_PER_SEC = 25;

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

static void handle_sighup(int sig) {
    reload_config = 1;
}

int main(int argc, char *argv[]) {
    struct config *old = NULL;
    struct config *cur = NULL;

    FILE          *fin = NULL;
    FILE          *fout = NULL;

    struct freedv *freedv;
    int            nin, nout;
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
                    "Could not open input data stream: %s",
                    cur->source_file);
        exit(1);
    }

    open_output_file(old, cur, &fout);
    if (fout == NULL) {
        log_message(logger,
                    LOG_ERROR,
                    "Could not open output voice stream: %s",
                    cur->dest_file);
        exit(1);
    }

    size_t key_bytes_read = read_key_file(cur->key_file, key);
    if (str_has_value(cur->key_file) && key_bytes_read != FREEDV_MASTER_KEY_LENGTH) {
        log_message(logger,
                    LOG_WARN,
                    "Truncated decryption key: Only %d bytes of a possible %d",
                    (int)key_bytes_read,
                    (int)FREEDV_MASTER_KEY_LENGTH);
    }

    freedv = freedv_open(FREEDV_MODE_2400B);
    if (freedv == NULL) {
        log_message(logger, LOG_ERROR, "Could not initialize voice demodulator");
        exit(1);
    }

    if (str_has_value(cur->key_file)) {
        freedv_set_crypto(freedv, key, iv);
    }
    else {
        log_message(logger, LOG_WARN, "Encryption disabled");
    }

    /* note use of API functions to tell us how big our buffers need to be -----*/
    
    short speech_out[freedv_get_n_max_speech_samples(freedv)];
    short demod_in[freedv_get_n_max_modem_samples(freedv)];

    /* Keep track of the number of consecutive silent frames. Initialize to
       FRAMES_PER_SEC to suppress output at startup if we aren't receiving
       anything */
    unsigned short silent_frames = FRAMES_PER_SEC;

    /* We need to work out how many samples the demod needs on each
       call (nin).  This is used to adjust for differences in the tx
       and rx sample clock frequencies.  Note also the number of
       output speech samples "nout" is time varying. */

    nin = freedv_nin(freedv);
    while(fread(demod_in, sizeof(short), nin, fin) == nin) {
        if (cur->vox_low > 0 && cur->vox_high > 0) {
            unsigned short rms_val = rms(demod_in, nin);
            log_message(logger, LOG_DEBUG, "Data RMS: %d", (int)rms_val);

            /* Reset counter */
            if (rms_val > cur->vox_high) {
                silent_frames = 0;
            }
            /* If a frame drops below iv_low or is between iv_low and iv_high after
               dropping below iv_low, increment the silent counter */
            else if (rms_val < cur->vox_low || silent_frames > 0) {
                /* Prevent overflow */
                if (silent_frames < USHRT_MAX) {
                    ++silent_frames;
                }

                log_message(logger,
                            LOG_DEBUG,
                            "Silent input data frame. Count: %d",
                            (int)silent_frames);

                /* Zero the output after a second */
                if (silent_frames > FRAMES_PER_SEC) {
                    memset(demod_in, 0, nin * sizeof(short));
                }
            }
        }

        nout = freedv_rx(freedv, speech_out, demod_in);

       /* IMPORTANT: don't forget to do this in the while loop to
           ensure we fread the correct number of samples: ie update
           "nin" before every call to freedv_rx()/freedv_comprx() */
        nin = freedv_nin(freedv);

        fwrite(speech_out, sizeof(short) * nout, 1, fout);
        fflush(fout);

        if (reload_config != 0) {
            log_message(logger, LOG_NOTICE, "Reloading receiver config\n");

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
                            "Could not open input data stream: %s",
                            cur->source_file);
                exit(1);
            }

            open_output_file(old, cur, &fout);
            if (fout == NULL) {
                log_message(logger,
                            LOG_ERROR,
                            "Could not open output voice stream: %s",
                            cur->dest_file);
                exit(1);
            }

            key_bytes_read = read_key_file(cur->key_file, key);
            if (str_has_value(cur->key_file) && key_bytes_read != FREEDV_MASTER_KEY_LENGTH) {
                log_message(logger,
                            LOG_WARN,
                            "Truncated decryption key: Only %d bytes of a possible %d",
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

    fclose(fin);
    fclose(fout);
    freedv_close(freedv);

    if (old != NULL) free(old);
    if (cur != NULL) free(cur);

    return 0;
}


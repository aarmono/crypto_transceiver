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

static void handle_sighup(int sig) {
    reload_config = 1;
}

int main(int argc, char *argv[]) {
    struct config *old = NULL;
    struct config *new = NULL;

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

    new = calloc(1, sizeof(struct config));
    read_config(argv[1], new);

    crypto_log logger = create_logger(new->log_file, new->log_level);

    open_input_file(old, new, &fin);
    if (fin == NULL) {
        log_message(logger, LOG_ERROR, "Could not open input file: %s", new->source_file);
        exit(1);
    }

    open_output_file(old, new, &fout);
    if (fout == NULL) {
        log_message(logger, LOG_ERROR, "Could not open output file: %s", new->dest_file);
        exit(1);
    }

    open_iv_file(old, new, &urandom);
    if (urandom == NULL) {
        log_message(logger, LOG_ERROR, "Unable to open random file: %s", new->random_file);
        exit(1);
    }

    if (fread(iv, sizeof(iv), 1, urandom) != 1) {
        log_message(logger, LOG_WARN, "Did not fully read initialization vector");
    }
    if (read_key_file(new->key_file, key) != FREEDV_MASTER_KEY_LENGTH) {
        log_message(logger, LOG_WARN, "Truncated key");
    }

    freedv = freedv_open(FREEDV_MODE_2400B);
    assert(freedv != NULL);

    freedv_set_crypto(freedv, key, iv);

    /* handy functions to set buffer sizes, note tx/modulator always
       returns freedv_get_n_nom_modem_samples() (unlike rx side) */
    int n_speech_samples = freedv_get_n_speech_samples(freedv);
    short speech_in[n_speech_samples];
    int n_nom_modem_samples = freedv_get_n_nom_modem_samples(freedv);
    short mod_out[n_nom_modem_samples];

    unsigned short silent_frames = 0;
    /* OK main loop  --------------------------------------- */
    while(fread(speech_in, sizeof(short), n_speech_samples, fin) == n_speech_samples) {
        if (new->vox_low > 0 && new->vox_high > 0) {
            short rms_val = rms(speech_in, n_speech_samples);
            log_message(logger, LOG_DEBUG, "RMS: %d", (int)rms_val);

            int reset_iv = 0;

            if (rms_val > new->vox_high && silent_frames > 0) {
                log_message(logger, LOG_INFO, "VOX activated. RMS: %d", (int)rms_val);
                silent_frames = 0;
            }
            /* If a frame drops below iv_low or is between iv_low and iv_high after
               dropping below iv_low, increment the silent counter */
            else if (rms_val < new->vox_low || silent_frames > 0) {
                ++silent_frames;
                log_message(logger, LOG_DEBUG, "Silent frame. Count: %d", (int)silent_frames);

                if (new->vox_period > 0 &&
                    (silent_frames == (25 * new->vox_period))) {
                    log_message(logger, LOG_INFO, "New IV from VOX. RMS: %d", (int)rms_val);
                    reset_iv = 1;
                }

                /* Reset IV every minute of silence (if configured)*/
                if (new->silent_period > 0 &&
                    (silent_frames % (25 * new->silent_period)) == 0) {
                    log_message(logger, LOG_INFO, "New IV from silence. RMS: %d", (int)rms_val);
                    reset_iv = 1;
                }
            }

            if (reset_iv) {
                if (fread(iv, sizeof(iv), 1, urandom) != 1) {
                    log_message(logger, LOG_WARN, "Did not fully read initialization vector");
                }
                freedv_set_crypto(freedv, NULL, iv);

                if (new->vox_cmd[0] != '\0') {
                    int stat = 0;
                    wait(&stat);

                    if (fork() == 0) {
                        _exit(system(new->vox_cmd));
                    }
                }
            }
        }

        freedv_tx(freedv, mod_out, speech_in);
        fwrite(mod_out, sizeof(short), n_nom_modem_samples, fout);

        if (reload_config != 0) {
            log_message(logger, LOG_NOTICE, "Reloading config");

            reload_config = 0;

            swap_config(&old, &new);
            if (new == NULL) {
                new = calloc(1, sizeof(struct config));
            }
            read_config(argv[1], new);

            if (strcmp(old->log_file, new->log_file) != 0) {
                destroy_logger(logger);
                logger = create_logger(new->log_file, new->log_level);
            }

            logger.level = new->log_level;

            open_input_file(old, new, &fin);
            if (fin == NULL) {
                log_message(logger, LOG_ERROR, "Could not open input file: %s", new->source_file);
                exit(1);
            }

            open_output_file(old, new, &fout);
            if (fout == NULL) {
                log_message(logger, LOG_ERROR, "Could not open output file: %s", new->dest_file);
                exit(1);
            }

            open_iv_file(old, new, &urandom);
            if (urandom == NULL) {
                log_message(logger, LOG_ERROR, "Unable to open random file: %s", new->random_file);
            }

            if (fread(iv, sizeof(iv), 1, urandom) != 1) {
                log_message(logger, LOG_WARN, "Did not fully read initialization vector");
            }
            if (read_key_file(new->key_file, key) != FREEDV_MASTER_KEY_LENGTH) {
                log_message(logger, LOG_WARN, "Truncated key");
            }

            freedv_set_crypto(freedv, key, iv);
        }
    }
    
    freedv_close(freedv);
    fclose(urandom);
    fclose(fin);
    fclose(fout);

    if (old != NULL) free(old);
    if (new != NULL) free(new);
    
    return 0;
}


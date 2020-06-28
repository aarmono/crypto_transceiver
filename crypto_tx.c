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

#include "freedv_api.h"
#include "crypto_cfg.h"

static short rms(short vals[], int len) {
    int64_t total = 0;
    for (int i = 0; i < len; ++i) {
        int64_t val = vals[i];
        total += val * val;
    }

    return (short)sqrt(total / len);
}

static volatile sig_atomic_t reload_config = 0;

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

    if (argc < 1) {
        printf("usage: %s ConfigFile\n", argv[0]);
        exit(1);
    }

    new = calloc(1, sizeof(struct config));
    read_config(argv[1], new);

    open_input_file(old, new, &fin);
    if (fin == NULL) {
        fprintf(stderr, "Could not open input file: %s\n", new->source_file);
        exit(1);
    }

    open_output_file(old, new, &fout);
    if (fout == NULL) {
        fprintf(stderr, "Could not open output file: %s\n", new->dest_file);
        exit(1);
    }

    open_iv_file(old, new, &urandom);
    if (urandom == NULL) {
        fprintf(stderr, "Unable to open random file: %s\n", new->random_file);
        exit(1);
    }

    if (fread(iv, sizeof(iv), 1, urandom) != 1) {
        fprintf(stderr, "WARN: did not fully read initialization vector\n");
    }
    if (read_key_file(new->key_file, key) != FREEDV_MASTER_KEY_LENGTH) {
        fprintf(stderr, "WARN: truncated key\n");
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
        if (new->iv_low > 0 && new->iv_high > 0) {
            short rms_val = rms(speech_in, n_speech_samples);

            /* Reset IV at the start of sound after a second of silence */
            if (rms_val > new->iv_high) {
                if (silent_frames >= 25) {
                    fprintf(stderr, "New IV!\n");
                    fread(iv, sizeof(iv), 1, urandom);
                    freedv_set_crypto(freedv, NULL, iv);
                }
                silent_frames = 0;
            }
            /* If a frame drops below iv_low or is between iv_low and iv_high after
               dropping below iv_low, increment the silent counter */
            else if (rms_val < new->iv_low || silent_frames > 0) {
                ++silent_frames;

                /* Reset IV every minute of silence */
                if ((silent_frames % (25 * new->silent_period)) == 0) {
                    fprintf(stderr, "New IV!\n");
                    fread(iv, sizeof(iv), 1, urandom);
                    freedv_set_crypto(freedv, NULL, iv);
                }
            }
        }

        freedv_tx(freedv, mod_out, speech_in);
        fwrite(mod_out, sizeof(short), n_nom_modem_samples, fout);

        if (reload_config != 0) {
            fprintf(stderr, "Reloading config\n");

            reload_config = 0;

            swap_config(&old, &new);
            if (new == NULL) {
                new = calloc(1, sizeof(struct config));
            }
            read_config(argv[1], new);

            open_input_file(old, new, &fin);
            if (fin == NULL) {
                fprintf(stderr, "Could not open input file: %s\n", new->source_file);
                exit(1);
            }

            open_output_file(old, new, &fout);
            if (fout == NULL) {
                fprintf(stderr, "Could not open output file: %s\n", new->dest_file);
                exit(1);
            }

            open_iv_file(old, new, &urandom);
            if (urandom == NULL) {
                fprintf(stderr, "Unable to open random file: %s\n", new->random_file);
            }

            if (fread(iv, sizeof(iv), 1, urandom) != sizeof(iv)) {
                fprintf(stderr, "WARN: did not fully read initialization vector\n");
            }
            if (read_key_file(new->key_file, key) != FREEDV_MASTER_KEY_LENGTH) {
                fprintf(stderr, "WARN: truncated key\n");
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


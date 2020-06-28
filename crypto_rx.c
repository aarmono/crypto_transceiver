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
#include <stdio.h>
#include <string.h>
#include <errno.h>
#include <stdlib.h>
#include <stdio.h>
#include <signal.h>

#include "freedv_api.h"
#include "crypto_cfg.h"

static volatile sig_atomic_t reload_config = 0;

int main(int argc, char *argv[]) {
    struct config *old = NULL;
    struct config *new = NULL;

    FILE          *fin = NULL;
    FILE          *fout = NULL;

    struct freedv *freedv;
    int            nin, nout;
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

    if (read_key_file(new->key_file, key) != FREEDV_MASTER_KEY_LENGTH) {
        fprintf(stderr, "WARN: truncated key\n");
    }

    freedv = freedv_open(FREEDV_MODE_2400B);
    assert(freedv != NULL);

    freedv_set_crypto(freedv, key, iv);

    /* note use of API functions to tell us how big our buffers need to be -----*/
    
    short speech_out[freedv_get_n_max_speech_samples(freedv)];
    short demod_in[freedv_get_n_max_modem_samples(freedv)];

    /* We need to work out how many samples the demod needs on each
       call (nin).  This is used to adjust for differences in the tx
       and rx sample clock frequencies.  Note also the number of
       output speech samples "nout" is time varying. */

    nin = freedv_nin(freedv);
    while(fread(demod_in, sizeof(short), nin, fin) == nin) {
        nout = freedv_rx(freedv, speech_out, demod_in);

       /* IMPORTANT: don't forget to do this in the while loop to
           ensure we fread the correct number of samples: ie update
           "nin" before every call to freedv_rx()/freedv_comprx() */
        nin = freedv_nin(freedv);

        fwrite(speech_out, sizeof(short), nout, fout);

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

            if (read_key_file(new->key_file, key) != FREEDV_MASTER_KEY_LENGTH) {
                fprintf(stderr, "WARN: truncated key\n");
            }

            freedv_set_crypto(freedv, key, iv);
        }
    }

    fclose(fin);
    fclose(fout);
    freedv_close(freedv);

    return 0;
}


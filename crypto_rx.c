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

#include <stdlib.h>
#include <stdio.h>
#include <errno.h>
#include <signal.h>

#include "crypto_rx_common.h"
#include "crypto_common.h"
#include "crypto_cfg.h"
#include "crypto_log.h"

static volatile sig_atomic_t reload_config = 0;

static void handle_sighup(int sig) {
    reload_config = 1;
}

int main(int argc, char *argv[]) {
    FILE* fin = stdin;
    FILE* fout = stdout;

    HCRYPTO_RX* crypto_rx = NULL;
    int         nin, nout;
    
    if (argc < 2) {
        fprintf(stderr, "usage: %s ConfigFile\n", argv[0]);
        exit(1);
    }

    signal(SIGHUP, handle_sighup);

    crypto_rx = crypto_rx_create("crypto_rx", argv[1]);
    if (crypto_rx == NULL) {
        fprintf(stderr, "Could not create crypto_rx object");
        exit(1);
    }

    /* note use of API functions to tell us how big our buffers need to be -----*/
    
    short* speech_out = malloc(sizeof(short) * crypto_rx_max_speech_samples_per_frame(crypto_rx));
    short* demod_in = malloc(sizeof(short) * crypto_rx_max_modem_samples_per_frame(crypto_rx));

    nin = crypto_rx_needed_modem_samples(crypto_rx);
    while(read_input_file(demod_in, nin, fin) == nin) {
        nout = crypto_rx_receive(crypto_rx, speech_out, demod_in);

        fwrite(speech_out, sizeof(short) * nout, 1, fout);
        fflush(fout);

        if (reload_config != 0) {
            reload_config = 0;

            crypto_rx_destroy(crypto_rx);
            crypto_rx = crypto_rx_create("crypto_rx", argv[1]);
            if (crypto_rx == NULL) {
                fprintf(stderr, "Could not create crypto_rx object");
                exit(1);
            }

            speech_out = realloc(speech_out, sizeof(short) * crypto_rx_max_speech_samples_per_frame(crypto_rx));
            demod_in = realloc(demod_in, sizeof(short) * crypto_rx_max_modem_samples_per_frame(crypto_rx));
        }

        /* IMPORTANT: don't forget to do this in the while loop to
           ensure we fread the correct number of samples: ie update
           "nin" before every call to freedv_rx()/freedv_comprx() */
        nin = crypto_rx_needed_modem_samples(crypto_rx);
    }

    free(speech_out);
    free(demod_in);
    fclose(fin);
    fclose(fout);
    crypto_rx_destroy(crypto_rx);

    return 0;
}


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

#include <stdlib.h>
#include <stdio.h>
#include <errno.h>
#include <signal.h>
#include <sys/wait.h>
#include <unistd.h>

#include "crypto_tx_common.h"
#include "crypto_common.h"
#include "crypto_cfg.h"
#include "crypto_log.h"

#ifndef TEMP_FAILURE_RETRY
#define TEMP_FAILURE_RETRY(expression) {int result; do result = (int)(expression); while (result == -1 && errno == EINTR); result;}
#endif

static volatile sig_atomic_t reload_config = 0;

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
    FILE *fin = stdin;
    FILE *fout = stdout;

    HCRYPTO_TX* crypto_tx = NULL;

    if (argc < 2) {
        fprintf(stderr, "usage: %s ConfigFile\n", argv[0]);
        exit(1);
    }

    signal(SIGHUP, handle_sighup);

    crypto_tx = crypto_tx_create(argv[1]);
    if (crypto_tx == NULL) {
        fprintf(stderr, "Could not create crypto_tx object");
        exit(1);
    }

    /* handy functions to set buffer sizes, note tx/modulator always
       returns freedv_get_n_nom_modem_samples() (unlike rx side) */
    int n_speech_samples = crypto_tx_speech_samples_per_frame(crypto_tx);
    int n_nom_modem_samples = crypto_tx_modem_samples_per_frame(crypto_tx);
    short* speech_in = malloc(sizeof(short) * n_speech_samples);
    short* mod_out = malloc(sizeof(short) * n_nom_modem_samples);

    /* OK main loop  --------------------------------------- */
    while(read_input_file(speech_in, n_speech_samples, fin) == n_speech_samples) {
        crypto_tx_transmit(crypto_tx, mod_out, speech_in);
        fwrite(mod_out, sizeof(short), n_nom_modem_samples, fout);

        if (reload_config != 0) {
            reload_config = 0;

            crypto_tx_destroy(crypto_tx);
            crypto_tx = crypto_tx_create(argv[1]);
            if (crypto_tx == NULL) {
                fprintf(stderr, "Could not create crypto_tx object");
                exit(1);
            }

            n_speech_samples = crypto_tx_speech_samples_per_frame(crypto_tx);
            n_nom_modem_samples = crypto_tx_modem_samples_per_frame(crypto_tx);

            speech_in = realloc(speech_in, sizeof(short) * n_speech_samples);
            mod_out = realloc(mod_out, sizeof(short) * n_nom_modem_samples);
        }
    }
    
    free(speech_in);
    free(mod_out);
    crypto_tx_destroy(crypto_tx);
    
    return 0;
}


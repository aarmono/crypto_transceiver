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
#include "crypto_cfg.h"
#include "crypto_log.h"

#ifndef TEMP_FAILURE_RETRY
#define TEMP_FAILURE_RETRY(expression) {int result; do result = (int)(expression); while (result == -1 && errno == EINTR); result;}
#endif

static volatile sig_atomic_t reload_config = 0;

static size_t read_input_file(short* buffer, size_t buffer_elems, FILE* file) {
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
    const struct config *old = NULL;
    const struct config *cur = NULL; 

    FILE *fin = NULL;
    FILE *fout = NULL;

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

    cur = crypto_tx_get_config(crypto_tx);

    open_input_file(old, cur, &fin);
    if (fin == NULL) {
        crypto_tx_log_to_logger(crypto_tx,
                                LOG_ERROR,
                                "Could not open input voice stream");
        exit(1);
    }

    open_output_file(old, cur, &fout);
    if (fout == NULL) {
        crypto_tx_log_to_logger(crypto_tx,
                                LOG_ERROR,
                                "Could not open output data stream");
        exit(1);
    }

    /* handy functions to set buffer sizes, note tx/modulator always
       returns freedv_get_n_nom_modem_samples() (unlike rx side) */
    int n_speech_samples = crypto_tx_speech_samples_per_frame(crypto_tx);
    short speech_in[n_speech_samples];
    int n_nom_modem_samples = crypto_tx_modem_samples_per_frame(crypto_tx);
    short mod_out[n_nom_modem_samples];

    /* OK main loop  --------------------------------------- */
    while(read_input_file(speech_in, n_speech_samples, fin) == n_speech_samples) {
        int reset_iv = 0;
        const int reload_config_this_loop = reload_config;

        reset_iv = crypto_tx_transmit(crypto_tx, mod_out, speech_in, reload_config_this_loop);
        fwrite(mod_out, sizeof(short), n_nom_modem_samples, fout);

        if (reset_iv) {
            try_system_async(cur->vox_cmd);
        }

        if (reload_config_this_loop != 0) {
            reload_config = 0;

            old = cur;
            cur = crypto_tx_get_config(crypto_tx);

            open_input_file(old, cur, &fin);
            if (fin == NULL) {
                crypto_tx_log_to_logger(crypto_tx,
                            LOG_ERROR,
                            "Could not open input voice stream");
                exit(1);
            }

            open_output_file(old, cur, &fout);
            if (fout == NULL) {
                crypto_tx_log_to_logger(crypto_tx,
                            LOG_ERROR,
                            "Could not open output data stream");
                exit(1);
            }
        }
    }
    
    crypto_tx_destroy(crypto_tx);
    
    return 0;
}


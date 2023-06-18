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
#include <stdlib.h>
#include <stdio.h>

#include "freedv_api.h"
#include "crypto_cfg.h"

int main(int argc, char *argv[]) {
    struct config *cur = NULL;

    struct freedv *freedv;
    
    if (argc < 2) {
        fprintf(stderr, "usage: %s ConfigFile\n", argv[0]);
        exit(1);
    }

    cur = calloc(1, sizeof(struct config));
    read_config(argv[1], cur);

    freedv = freedv_open(cur->freedv_mode);
    if (freedv == NULL) {
        exit(1);
    }

    printf("%d", freedv_get_modem_sample_rate(freedv));

    freedv_close(freedv);
    if (cur != NULL) free(cur);

    return 0;
}


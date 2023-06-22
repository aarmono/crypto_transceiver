#include <stdlib.h>
#include <math.h>

#include "freedv_api.h"

#include "crypto_common.h"

short rms(const short vals[], int len) {
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

size_t read_input_file(short* buffer, size_t buffer_elems, FILE* file){
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

void configure_freedv(struct freedv* f){
    freedv_set_squelch_en(f, 1);
    // Settings borrowed from sm1000_main.c
    const int mode = freedv_get_mode(f);
    switch(mode) {
        case FREEDV_MODE_700C:
            freedv_set_snr_squelch_thresh(f, 2.0);
            freedv_set_eq(f, 1);

            freedv_set_clip(f, 1);
            break;
        case FREEDV_MODE_700D:
            freedv_set_snr_squelch_thresh(f, -2.0);
            freedv_set_eq(f, 1);

            freedv_set_clip(f, 1);
            freedv_set_tx_bpf(f, 1);
            break;
        case FREEDV_MODE_700E:
            freedv_set_snr_squelch_thresh(f, 0.0);
            freedv_set_eq(f, 1);

            freedv_set_clip(f, 1);
            freedv_set_tx_bpf(f, 1);
            break;
        case FREEDV_MODE_800XA:
            freedv_set_eq(f, 1);
            break;
    }
}

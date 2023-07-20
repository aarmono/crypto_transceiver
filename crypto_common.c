#include <stdlib.h>
#include <stdint.h>

#include "freedv_api.h"

#include "crypto_common.h"
#include "crypto_cfg.h"

// Square root of integer
// From: https://en.wikipedia.org/wiki/Integer_square_root
uint64_t int_sqrt(uint64_t s)
{
    // Zero yields zero
    // One yields one
    if (s <= 1) 
        return s;

    // Initial estimate (must be too high)
    uint64_t x0 = s / 2;

    // Update
    uint64_t x1 = (x0 + s / x0) / 2;

    while (x1 < x0) // Bound check
    {
        x0 = x1;
        x1 = (x0 + s / x0) / 2;
    }
    return x0;
}

short rms(const short vals[], size_t len) {
    if (len > 0) {
        uint64_t total = 0;
        for (int i = 0; i < len; ++i) {
            int64_t val = vals[i];
            total += (uint64_t)(val * val);
        }

        return (short)int_sqrt(total / len);
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

void configure_freedv(struct freedv* f, const struct config* cfg){
    freedv_set_squelch_en(f, cfg->freedv_squelch_enabled);
    // Settings borrowed from sm1000_main.c
    const int mode = freedv_get_mode(f);
    switch(mode) {
        case FREEDV_MODE_700C:
            freedv_set_snr_squelch_thresh(f, cfg->freedv_squelch_thresh_700c);
            freedv_set_eq(f, 1);

            freedv_set_clip(f, 1);
            break;
        case FREEDV_MODE_700D:
            freedv_set_snr_squelch_thresh(f, cfg->freedv_squelch_thresh_700d);
            freedv_set_eq(f, 1);

            freedv_set_clip(f, 1);
            freedv_set_tx_bpf(f, 1);
            break;
        case FREEDV_MODE_700E:
            freedv_set_snr_squelch_thresh(f, cfg->freedv_squelch_thresh_700e);
            freedv_set_eq(f, 1);

            freedv_set_clip(f, 1);
            freedv_set_tx_bpf(f, 1);
            break;
        case FREEDV_MODE_800XA:
            freedv_set_eq(f, 1);
            break;
    }
}

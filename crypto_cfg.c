#include <string.h>
#include <stdio.h>
#include <stdlib.h>

#include "crypto_cfg.h"
#include "minIni.h"
#include "freedv_api.h"

static int ini_callback(const mTCHAR *Section, const mTCHAR *Key, const mTCHAR *Value, void *UserData) {
    struct config *cfg = (struct config*)UserData;

    if (strcasecmp(Section, "Audio IO") ==0) {
        if (strcasecmp(Key, "Source") == 0) {
            strncpy(cfg->source_file, Value, sizeof(cfg->source_file) - 1);
        }
        else if (strcasecmp(Key, "BufferSource") == 0) {
            cfg->source_file_buffer = strcasecmp(Value, "true") == 0 ||
                                      strcasecmp(Value, "yes") == 0;
        }
        else if (strcasecmp(Key, "Dest") == 0) {
            strncpy(cfg->dest_file, Value, sizeof(cfg->dest_file) - 1);
        }
        else if (strcasecmp(Key, "BufferDest") == 0) {
            cfg->dest_file_buffer = strcasecmp(Value, "true") == 0 ||
                                    strcasecmp(Value, "yes") == 0;
        }
    }
    else if (strcasecmp(Section, "Crypto IO") ==0) {
        if (strcasecmp(Key, "KeyFile") == 0) {
            strncpy(cfg->key_file, Value, sizeof(cfg->key_file) - 1);
        }
        else if (strcasecmp(Key, "RandomFile") == 0) {
            strncpy(cfg->random_file, Value, sizeof(cfg->random_file) - 1);
        }
    }
    else if (strcasecmp(Section, "Rekeying") ==0) {
        if (strcasecmp(Key, "QuietRekey") == 0) {
            cfg->silent_period = atoi(Value);
        }
    }
    else if (strcasecmp(Section, "Diagnostics") ==0) {

    }
    else if (strcasecmp(Section, "Audio") == 0) {
        if (strcasecmp(Key, "VOXQuiet") == 0) {
            cfg->vox_low = atoi(Value);
        }
        else if (strcasecmp(Key, "VOXNoise") == 0) {
            cfg->vox_high = atoi(Value);
        }
    }

    return 1;
}

void read_config(const char* config_file, struct config* cfg) {
    memset(cfg, 0, sizeof(struct config));
    ini_browse(ini_callback, (void*)cfg, config_file);
}

void open_output_file(const struct config* old, const struct config* new, FILE** f) {
    if (old == NULL || strcasecmp(old->dest_file, new->dest_file) != 0) {
        if (*f != NULL && *f != stdout) fclose(*f);

        *f = strcasecmp(new->dest_file, "stdout") == 0 ? stdout : fopen(new->dest_file, "wb");
        if (*f != NULL && !new->dest_file_buffer) setbuf(*f, NULL);
    }
}

void open_input_file(const struct config* old, const struct config* new, FILE** f) {
    if (old == NULL || strcasecmp(old->source_file, new->source_file) != 0) {
        if (*f != NULL && *f != stdin) fclose(*f);

        *f = strcasecmp(new->source_file, "stdin") == 0 ? stdin : fopen(new->source_file, "rb");
        if (*f != NULL && !new->source_file_buffer) setbuf(*f, NULL);
    }
}

void open_iv_file(const struct config* old, const struct config* new, FILE** f) {
    if (old == NULL || strcasecmp(old->random_file, new->random_file) != 0) {
        if (*f != NULL) fclose(*f);

        *f = fopen(new->random_file, "rb");
    }
}

size_t read_key_file(const char* key_file, unsigned char key[]) {
    FILE* f = fopen(key_file, "rb");
    if (f == NULL) return 0;

    size_t ret = fread(key, 1, FREEDV_MASTER_KEY_LENGTH, f);
    fclose(f);

    return ret;
}
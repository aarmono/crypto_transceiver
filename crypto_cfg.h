#ifndef CRYPTO_CFG
#define CRYPTO_CFG

struct config
{
    char source_file[80];
    int  source_file_buffer;
    char dest_file[80];
    int  dest_file_buffer;

    char key_file[80];
    char random_file[80];

    char log_file[80];
    int  log_level;

    int  vox_low;
    int  vox_high;
    int  silent_period;
    int  vox_period;
    char vox_cmd[80];

    int  freedv_mode;
};

void read_config(const char* config_file, struct config* cfg);

void open_output_file(const struct config* old, const struct config* new, FILE** f);
void open_input_file(const struct config* old, const struct config* new, FILE** f);
void open_iv_file(const struct config* old, const struct config* new, FILE** f);
size_t read_key_file(const char* key_file, unsigned char key[]);

static void swap_config(struct config** old, struct config** new) {
    struct config* tmp = *old;
    *old = *new;
    *new = tmp;
}

static inline int str_has_value(const char* str) {
    return str != NULL && str[0] != '\0';
}

#endif
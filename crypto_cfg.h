#ifndef CRYPTO_CFG
#define CRYPTO_CFG

#ifdef __cplusplus
extern "C" {
#endif

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
    int  freedv_clip;
};

void read_config(const char* config_file, struct config* cfg);

void open_output_file(const struct config* old, const struct config* next, FILE** f);
void open_input_file(const struct config* old, const struct config* next, FILE** f);
void open_iv_file(const struct config* old, const struct config* next, FILE** f);
size_t read_key_file(const char* key_file, unsigned char key[]);

static void swap_config(struct config** old, struct config** next) {
    struct config* tmp = *old;
    *old = *next;
    *next = tmp;
}

static inline int str_has_value(const char* str) {
    return str != NULL && str[0] != '\0';
}

#ifdef __cplusplus
}
#endif

#endif
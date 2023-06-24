#ifndef CRYPTO_CFG
#define CRYPTO_CFG

#ifdef __cplusplus
extern "C" {
#endif

struct config
{
    char key_file[80];

    char log_file[80];
    int  log_level;

    int  vox_low;
    int  vox_high;
    int  silent_period;
    int  vox_period;

    int  freedv_mode;

    int  jack_period_700c;
    int  jack_period_700d;
    int  jack_period_700e;
    int  jack_period_800xa;
    int  jack_period_1600;
    int  jack_period_2400b;
};

void read_config(const char* config_file, struct config* cfg);

size_t read_key_file(const char* key_file, unsigned char key[]);
int get_jack_period(const struct config* cfg);

static inline int str_has_value(const char* str) {
    return str != NULL && str[0] != '\0';
}

#ifdef __cplusplus
}
#endif

#endif
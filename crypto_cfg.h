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

    int modem_quiet_max_thresh;
    int modem_signal_min_thresh;
    int modem_num_quiet_flush_frames;
    int voice_quiet_max_thresh;
    int voice_signal_min_thresh;

    int  rekey_period;
    int  crypto_enabled;

    int  ptt_enabled;
    int  ptt_gpio_num;
    int  ptt_active_low;
    char ptt_gpio_bias[80];

    int  ptt_output_gpio_num;
    int  ptt_output_active_low;
    char ptt_output_bias[80];
    char ptt_output_drive[80];

    int  freedv_mode;

    int  jack_tx_period_700c;
    int  jack_tx_period_700d;
    int  jack_tx_period_700e;
    int  jack_tx_period_800xa;
    int  jack_tx_period_1600;
    int  jack_tx_period_2400b;

    int  jack_rx_period_700c;
    int  jack_rx_period_700d;
    int  jack_rx_period_700e;
    int  jack_rx_period_800xa;
    int  jack_rx_period_1600;
    int  jack_rx_period_2400b;

    char jack_secure_notify_file[80];
    char jack_insecure_notify_file[80];

    char jack_voice_in_port[80];
    char jack_modem_out_port[80];

    char jack_modem_in_port[80];
    char jack_voice_out_port[80];
    char jack_notify_out_port[80];
};

void read_config(const char* config_file, struct config* cfg);

size_t read_key_file(const char* key_file, unsigned char key[]);

static inline int str_has_value(const char* str) {
    return str != NULL && str[0] != '\0';
}

#ifdef __cplusplus
}
#endif

#endif
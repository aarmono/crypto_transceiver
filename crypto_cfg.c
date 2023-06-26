#include <string.h>
#include <stdio.h>
#include <stdlib.h>

#include "freedv_api.h"
#include "crypto_cfg.h"
#include "minIni.h"

static int ini_callback(const mTCHAR *Section, const mTCHAR *Key, const mTCHAR *Value, void *UserData) {
    struct config *cfg = (struct config*)UserData;

    if (strcasecmp(Section, "Crypto IO") ==0) {
        if (strcasecmp(Key, "KeyFile") == 0) {
            strncpy(cfg->key_file, Value, sizeof(cfg->key_file) - 1);
        }
    }
    else if (strcasecmp(Section, "Crypto") ==0) {
        if (strcasecmp(Key, "AutoRekey") == 0) {
            cfg->rekey_period = atoi(Value);
        }
        else if (strcasecmp(Key, "Enabled") == 0) {
            cfg->crypto_enabled = atoi(Value);
        }
    }
    else if (strcasecmp(Section, "Audio") == 0) {
        if (strcasecmp(Key, "ModemQuietMaxThresh") == 0) {
            cfg->modem_quiet_max_thresh = atoi(Value);
        }
        else if (strcasecmp(Key, "ModemSignalMinThresh") == 0) {
            cfg->modem_signal_min_thresh = atoi(Value);
        }
        else if (strcasecmp(Key, "VoiceQuietMaxThresh") == 0) {
            cfg->voice_quiet_max_thresh = atoi(Value);
        }
        else if (strcasecmp(Key, "VoiceSignalMinThresh") == 0) {
            cfg->voice_signal_min_thresh = atoi(Value);
        }
    }
    else if (strcasecmp(Section, "Diagnostics") ==0) {
        if (strcasecmp(Key, "LogFile") == 0) {
            strncpy(cfg->log_file, Value, sizeof(cfg->log_file) - 1);
        }
        else if (strcasecmp(Key, "LogLevel") == 0) {
            cfg->log_level = atoi(Value);
        }
    }
    else if (strcasecmp(Section, "Codec") == 0) {
        if (strcasecmp(Key, "Mode") == 0) {
            if (!strcasecmp(Value,"1600")) cfg->freedv_mode = FREEDV_MODE_1600;
            if (!strcasecmp(Value,"700C")) cfg->freedv_mode = FREEDV_MODE_700C;
            if (!strcasecmp(Value,"700D")) cfg->freedv_mode = FREEDV_MODE_700D;
            if (!strcasecmp(Value,"700E")) cfg->freedv_mode = FREEDV_MODE_700E;
            if (!strcasecmp(Value,"2400A")) cfg->freedv_mode = FREEDV_MODE_2400A;
            if (!strcasecmp(Value,"2400B")) cfg->freedv_mode = FREEDV_MODE_2400B;
            if (!strcasecmp(Value,"800XA")) cfg->freedv_mode = FREEDV_MODE_800XA;
        }
    }
    else if (strcasecmp(Section, "JACK") == 0) {
        if (strcasecmp(Key, "TXPeriod700C") == 0) {
            cfg->jack_tx_period_700c = atoi(Value);
        }
        else if (strcasecmp(Key, "TXPeriod700D") == 0){
            cfg->jack_tx_period_700d = atoi(Value);
        }
        else if (strcasecmp(Key, "TXPeriod700E") == 0){
            cfg->jack_tx_period_700e = atoi(Value);
        }
        else if (strcasecmp(Key, "TXPeriod800XA") == 0){
            cfg->jack_tx_period_800xa = atoi(Value);
        }
        else if (strcasecmp(Key, "TXPeriod1600") == 0){
            cfg->jack_tx_period_1600 = atoi(Value);
        }
        else if (strcasecmp(Key, "TXPeriod2400B") == 0){
            cfg->jack_tx_period_2400b = atoi(Value);
        }

        else if (strcasecmp(Key, "RXPeriod700C") == 0) {
            cfg->jack_rx_period_700c = atoi(Value);
        }
        else if (strcasecmp(Key, "RXPeriod700D") == 0){
            cfg->jack_rx_period_700d = atoi(Value);
        }
        else if (strcasecmp(Key, "RXPeriod700E") == 0){
            cfg->jack_rx_period_700e = atoi(Value);
        }
        else if (strcasecmp(Key, "RXPeriod800XA") == 0){
            cfg->jack_rx_period_800xa = atoi(Value);
        }
        else if (strcasecmp(Key, "RXPeriod1600") == 0){
            cfg->jack_rx_period_1600 = atoi(Value);
        }
        else if (strcasecmp(Key, "RXPeriod2400B") == 0){
            cfg->jack_rx_period_2400b = atoi(Value);
        }

        else if (strcasecmp(Key, "SecureNotifyFile") == 0) {
            strncpy(cfg->jack_secure_notify_file,
                    Value,
                    sizeof(cfg->jack_secure_notify_file) - 1);
        }
        else if (strcasecmp(Key, "InsecureNotifyFile") == 0) {
            strncpy(cfg->jack_insecure_notify_file,
                    Value,
                    sizeof(cfg->jack_insecure_notify_file) - 1);
        }

        else if (strcasecmp(Key, "VoiceInPort") == 0) {
            strncpy(cfg->jack_voice_in_port,
                    Value,
                    sizeof(cfg->jack_voice_in_port) - 1);
        }
        else if (strcasecmp(Key, "ModemOutPort") == 0) {
            strncpy(cfg->jack_modem_out_port,
                    Value,
                    sizeof(cfg->jack_modem_out_port) - 1);
        }
        else if (strcasecmp(Key, "ModemInPort") == 0) {
            strncpy(cfg->jack_modem_in_port,
                    Value,
                    sizeof(cfg->jack_modem_in_port) - 1);
        }
        else if (strcasecmp(Key, "VoiceOutPort") == 0) {
            strncpy(cfg->jack_voice_out_port,
                    Value,
                    sizeof(cfg->jack_voice_out_port) - 1);
        }
        else if (strcasecmp(Key, "NotifyOutPort") == 0) {
            strncpy(cfg->jack_notify_out_port,
                    Value,
                    sizeof(cfg->jack_notify_out_port) - 1);
        }
    }

    return 1;
}

void read_config(const char* config_file, struct config* cfg) {
    memset(cfg, 0, sizeof(struct config));
    cfg->freedv_mode = FREEDV_MODE_2400B;
    ini_browse(ini_callback, (void*)cfg, config_file);
}

size_t read_key_file(const char* key_file, unsigned char key[]) {
    memset(key, 0, FREEDV_MASTER_KEY_LENGTH);

    if (str_has_value(key_file)) {
        FILE* f = fopen(key_file, "rb");
        if (f == NULL) return 0;

        size_t ret = fread(key, 1, FREEDV_MASTER_KEY_LENGTH, f);
        fclose(f);

        return ret;
    }
    else {
        return 0;
    }
}

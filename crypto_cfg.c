#include <string.h>
#include <stdio.h>
#include <stdlib.h>

#include "crypto_cfg.h"
#include "minIni.h"
#include "freedv_api.h"

static int ini_callback(const mTCHAR *Section, const mTCHAR *Key, const mTCHAR *Value, void *UserData) {
    struct config *cfg = (struct config*)UserData;

    if (strcasecmp(Section, "Crypto IO") ==0) {
        if (strcasecmp(Key, "KeyFile") == 0) {
            strncpy(cfg->key_file, Value, sizeof(cfg->key_file) - 1);
        }
    }
    else if (strcasecmp(Section, "Crypto") ==0) {
        if (strcasecmp(Key, "QuietRekey") == 0) {
            cfg->silent_period = atoi(Value);
        }
        else if (strcasecmp(Key, "VOXRekey") == 0) {
            cfg->vox_period = atoi(Value);
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
    else if (strcasecmp(Section, "Audio") == 0) {
        if (strcasecmp(Key, "VOXQuiet") == 0) {
            cfg->vox_low = atoi(Value);
        }
        else if (strcasecmp(Key, "VOXNoise") == 0) {
            cfg->vox_high = atoi(Value);
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
        if (strcasecmp(Key, "Period700C") == 0) {
            cfg->jack_period_700c = atoi(Value);
        }
        else if (strcasecmp(Key, "Period700D") == 0){
            cfg->jack_period_700d = atoi(Value);
        }
        else if (strcasecmp(Key, "Period700E") == 0){
            cfg->jack_period_700e = atoi(Value);
        }
        else if (strcasecmp(Key, "Period800XA") == 0){
            cfg->jack_period_800xa = atoi(Value);
        }
        else if (strcasecmp(Key, "Period1600") == 0){
            cfg->jack_period_1600 = atoi(Value);
        }
        else if (strcasecmp(Key, "Period2400B") == 0){
            cfg->jack_period_2400b = atoi(Value);
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

int get_jack_period(const struct config* cfg)
{
    switch(cfg->freedv_mode)
    {
        case FREEDV_MODE_700C:
            return cfg->jack_period_700c;
        case FREEDV_MODE_700D:
            return cfg->jack_period_700d;
        case FREEDV_MODE_700E:
            return cfg->jack_period_700e;
        case FREEDV_MODE_800XA:
            return cfg->jack_period_800xa;
        case FREEDV_MODE_1600:
            return cfg->jack_period_1600;
        case FREEDV_MODE_2400B:
            return cfg->jack_period_2400b;
        default:
            return 0;
    }
}

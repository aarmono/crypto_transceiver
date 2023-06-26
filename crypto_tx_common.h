#ifndef CRYPTO_TX_COMMON_H
#define CRYPTO_TX_COMMON_H

struct config;

#ifdef __cplusplus

#include <memory>

class crypto_tx_common
{
public:
    crypto_tx_common(const char* name, const char* config_file_path);
    ~crypto_tx_common();

    size_t speech_samples_per_frame() const;
    size_t modem_samples_per_frame() const;

    uint speech_sample_rate() const;
    uint modem_sample_rate() const;

    const struct config* get_config() const;

    void log_to_logger(int level, const char* msg);

    void force_rekey_next_frame();

    size_t transmit(short* mod_out, const short* speech_in);

private:
    struct tx_parms;

private:
    const std::unique_ptr<tx_parms> m_parms;
};

extern "C"
{
#endif

struct HCRYPTO_TX;
typedef struct HCRYPTO_TX HCRYPTO_TX;

HCRYPTO_TX* crypto_tx_create(const char* name, const char* config_file_path);
void crypto_tx_destroy(HCRYPTO_TX* hnd);

int crypto_tx_speech_samples_per_frame(HCRYPTO_TX* hnd);
int crypto_tx_modem_samples_per_frame(HCRYPTO_TX* hnd);

const struct config* crypto_tx_get_config(HCRYPTO_TX* hnd);

void crypto_tx_log_to_logger(HCRYPTO_TX* hnd, int level, const char* msg);

int crypto_tx_transmit(HCRYPTO_TX* hnd, short* mod_out, const short* speech_in);

#ifdef __cplusplus
} // extern "C"
#endif

#endif

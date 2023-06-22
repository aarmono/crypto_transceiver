#ifndef CRYPTO_RX_COMMON_H
#define CRYPTO_RX_COMMON_H

struct config;

#ifdef __cplusplus

#include <memory>

class crypto_rx_common
{
public:
    crypto_rx_common(const char* config_file_path);
    ~crypto_rx_common();

    size_t max_speech_samples_per_frame() const;
    size_t max_modem_samples_per_frame() const;
    size_t modem_samples_per_frame() const;

    size_t needed_modem_samples() const;

    bool is_synced() const;

    uint speech_sample_rate() const;
    uint modem_sample_rate() const;

    const struct config* get_config() const;

    void log_to_logger(int level, const char* msg);

    size_t receive(short* speech_out,
                   short* demod_in,
                   bool   reload_config = false);

private:
    struct rx_parms;

private:
    int modem_frames_per_second() const;

private:
    const std::unique_ptr<rx_parms> m_parms;
};

extern "C"
{
#endif

struct HCRYPTO_RX;
typedef struct HCRYPTO_RX HCRYPTO_RX;

HCRYPTO_RX* crypto_rx_create(const char* config_file_path);
void crypto_rx_destroy(HCRYPTO_RX* hnd);

int crypto_rx_max_speech_samples_per_frame(HCRYPTO_RX* hnd);
int crypto_rx_max_modem_samples_per_frame(HCRYPTO_RX* hnd);

int crypto_rx_needed_modem_samples(HCRYPTO_RX* hnd);

const struct config* crypto_rx_get_config(HCRYPTO_RX* hnd);

void crypto_rx_log_to_logger(HCRYPTO_RX* hnd, int level, const char* msg);

int crypto_rx_receive(HCRYPTO_RX* hnd, short* speech_out, short* demod_in, int reload_config);

#ifdef __cplusplus
} // extern "C"
#endif

#endif

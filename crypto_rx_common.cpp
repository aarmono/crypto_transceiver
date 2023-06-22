/*---------------------------------------------------------------------------*\

  Originally derived from freedv_rx with modifications

\*---------------------------------------------------------------------------*/

/*

  This program is free software; you can redistribute it and/or modify
  it under the terms of the GNU Lesser General Public License version 2.1, as
  published by the Free Software Foundation.  This program is
  distributed in the hope that it will be useful, but WITHOUT ANY
  WARRANTY; without even the implied warranty of MERCHANTABILITY or
  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public
  License for more details.

  You should have received a copy of the GNU Lesser General Public License
  along with this program; if not, see <http://www.gnu.org/licenses/>.
*/

#include <cstring>
#include <cmath>
#include <climits>
#include <string>
#include <memory>
#include <stdexcept>

#include "freedv_api.h"
#include "crypto_cfg.h"
#include "crypto_log.h"

#include "crypto_rx_common.h"

using namespace std;

#define IV_LEN 16
static const unsigned short FRAMES_PER_SEC = 25;

static short rms(const short vals[], int len) {
    if (len > 0) {
        int64_t total = 0;
        for (int i = 0; i < len; ++i) {
            int64_t val = vals[i];
            total += val * val;
        }

        return (short)sqrt(total / len);
    }
    else {
        return 0;
    }
}

struct crypto_rx_common::rx_parms
{
    rx_parms(const char* cfg)
        : config_file(cfg)
    {
        memset(&logger, 0, sizeof(logger));
    }
    ~rx_parms()
    {
        if (old != nullptr) free(old);
        if (cur != nullptr) free(cur);
        if (freedv != nullptr) freedv_close(freedv);
        destroy_logger(logger);
    }

    const string   config_file;
    struct config* old = nullptr;
    struct config* cur = nullptr;
    struct freedv* freedv = nullptr;
    crypto_log     logger;
    unsigned short silent_frames = 0;
};

crypto_rx_common::~crypto_rx_common() {}

crypto_rx_common::crypto_rx_common(const char* config_file)
    : m_parms(new rx_parms(config_file))
{
    unsigned char  key[FREEDV_MASTER_KEY_LENGTH];
    unsigned char  iv[IV_LEN];

    m_parms->cur = static_cast<struct config*>(calloc(1, sizeof(struct config)));
    read_config(config_file, m_parms->cur);

    m_parms->logger = create_logger(m_parms->cur->log_file, m_parms->cur->log_level);

    size_t key_bytes_read = read_key_file(m_parms->cur->key_file, key);
    if (str_has_value(m_parms->cur->key_file) &&
        key_bytes_read != FREEDV_MASTER_KEY_LENGTH) {
        log_message(m_parms->logger,
                    LOG_WARN,
                    "Truncated decryption key: Only %d bytes of a possible %d",
                    (int)key_bytes_read,
                    (int)FREEDV_MASTER_KEY_LENGTH);
    }

    m_parms->freedv = freedv_open(m_parms->cur->freedv_mode);
    if (m_parms->freedv == NULL) {
        log_message(m_parms->logger, LOG_ERROR, "Could not initialize voice demodulator");
        throw runtime_error("Could not initialize voice demodulator");
    }

    if (str_has_value(m_parms->cur->key_file)) {
        freedv_set_crypto(m_parms->freedv, key, iv);
    }
    else {
        log_message(m_parms->logger, LOG_WARN, "Encryption disabled");
    }

    m_parms->silent_frames = FRAMES_PER_SEC;
}

size_t crypto_rx_common::max_speech_samples_per_frame() const
{
    return freedv_get_n_max_speech_samples(m_parms->freedv);
}

size_t crypto_rx_common::max_modem_samples_per_frame() const
{
    return freedv_get_n_max_modem_samples(m_parms->freedv);
}

size_t crypto_rx_common::needed_modem_samples() const
{
    return freedv_nin(m_parms->freedv);
}

uint crypto_rx_common::speech_sample_rate() const
{
    return freedv_get_speech_sample_rate(m_parms->freedv);
}

uint crypto_rx_common::modem_sample_rate() const
{
    return freedv_get_modem_sample_rate(m_parms->freedv);
}

const struct config* crypto_rx_common::get_config() const
{
    return m_parms->cur;
}

void crypto_rx_common::log_to_logger(int level, const char* msg)
{
    log_message(m_parms->logger, level, "%s", msg);
}

size_t crypto_rx_common::receive(short* speech_out,
                                 short* demod_in,
                                 bool   reload_config)
{
    const int nin = freedv_nin(m_parms->freedv);
    if (m_parms->cur->vox_low > 0 && m_parms->cur->vox_high > 0) {
        unsigned short rms_val = rms(demod_in, nin);
        log_message(m_parms->logger, LOG_DEBUG, "Data RMS: %d", (int)rms_val);

        /* Reset counter */
        if (rms_val > m_parms->cur->vox_high) {
            m_parms->silent_frames = 0;
        }
        /* If a frame drops below iv_low or is between iv_low and iv_high after
           dropping below iv_low, increment the silent counter */
        else if (rms_val < m_parms->cur->vox_low || m_parms->silent_frames > 0) {
            /* Prevent overflow */
            if (m_parms->silent_frames < USHRT_MAX) {
                ++m_parms->silent_frames;
            }

            log_message(m_parms->logger,
                        LOG_DEBUG,
                        "Silent input data frame. Count: %d",
                        (int)m_parms->silent_frames);

            /* Zero the output after a second */
            if (m_parms->silent_frames > FRAMES_PER_SEC) {
                memset(demod_in, 0, nin * sizeof(short));
            }
        }
    }

    const size_t nout = freedv_rx(m_parms->freedv, speech_out, demod_in);

    if (reload_config == true) {
        log_message(m_parms->logger, LOG_NOTICE, "Reloading receiver config\n");

        swap(m_parms->old, m_parms->cur);
        if (m_parms->cur == NULL) {
            m_parms->cur = static_cast<struct config*>(calloc(1, sizeof(struct config)));
        }
        read_config(m_parms->config_file.c_str(), m_parms->cur);

        if (strcmp(m_parms->old->log_file, m_parms->cur->log_file) != 0) {
            destroy_logger(m_parms->logger);
            m_parms->logger = create_logger(m_parms->cur->log_file,
                                            m_parms->cur->log_level);
        }

        m_parms->logger.level = m_parms->cur->log_level;

        unsigned char key[FREEDV_MASTER_KEY_LENGTH];
        const size_t key_bytes_read = read_key_file(m_parms->cur->key_file, key);
        if (str_has_value(m_parms->cur->key_file) &&
            key_bytes_read != FREEDV_MASTER_KEY_LENGTH)
        {
            log_message(m_parms->logger,
                        LOG_WARN,
                        "Truncated decryption key: Only %d bytes of a possible %d",
                        (int)key_bytes_read,
                        (int)FREEDV_MASTER_KEY_LENGTH);
        }

        if (str_has_value(m_parms->cur->key_file)) {
            unsigned char  iv[IV_LEN];
            freedv_set_crypto(m_parms->freedv, key, iv);
        }
        else {
            log_message(m_parms->logger, LOG_WARN, "Encryption disabled");
            freedv_set_crypto(m_parms->freedv, NULL, NULL);
        }
    }

    return nout;
}

HCRYPTO_RX* crypto_rx_create(const char* config_file_path)
{
    try
    {
        return reinterpret_cast<HCRYPTO_RX*>(new crypto_rx_common(config_file_path));
    }
    catch (...)
    {
        return NULL;
    }
}

void crypto_rx_destroy(HCRYPTO_RX* hnd)
{
    delete reinterpret_cast<crypto_rx_common*>(hnd);
}

int crypto_rx_max_speech_samples_per_frame(HCRYPTO_RX* hnd)
{
    return reinterpret_cast<crypto_rx_common*>(hnd)->max_speech_samples_per_frame();
}

int crypto_rx_max_modem_samples_per_frame(HCRYPTO_RX* hnd)
{
    return reinterpret_cast<crypto_rx_common*>(hnd)->max_modem_samples_per_frame();
}

int crypto_rx_needed_modem_samples(HCRYPTO_RX* hnd)
{
    return reinterpret_cast<crypto_rx_common*>(hnd)->needed_modem_samples();
}

const struct config* crypto_rx_get_config(HCRYPTO_RX* hnd)
{
    return reinterpret_cast<crypto_rx_common*>(hnd)->get_config();
}

void crypto_rx_log_to_logger(HCRYPTO_RX* hnd, int level, const char* msg)
{
    return reinterpret_cast<crypto_rx_common*>(hnd)->log_to_logger(level, msg);
}

int crypto_rx_receive(HCRYPTO_RX* hnd, short* speech_out, short* demod_in, int reload_config)
{
    return reinterpret_cast<crypto_rx_common*>(hnd)->receive(speech_out, demod_in, reload_config);
}

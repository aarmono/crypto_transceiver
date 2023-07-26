/*---------------------------------------------------------------------------*\

  Originally derived from freedv_tx with modifications

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
#include <sys/random.h>

#include <cstring>
#include <cmath>

#include <string>
#include <memory>
#include <stdexcept>

#include "freedv_api.h"
#include "crypto_cfg.h"
#include "crypto_log.h"

#include "crypto_tx_common.h"
#include "crypto_common.h"

using namespace std;

struct crypto_tx_common::tx_parms
{
    tx_parms()
    {
        memset(&logger, 0, sizeof(logger));
    }
    ~tx_parms()
    {
        if (cur != nullptr) free(cur);
        if (freedv != nullptr) freedv_close(freedv);
        destroy_logger(logger);
    }

    struct config* cur = nullptr;
    struct freedv* freedv = nullptr;
    crypto_log     logger;
    unsigned short frames_since_rekey = 0;
    bool           force_rekey = false;
};

crypto_tx_common::~crypto_tx_common() {}

crypto_tx_common::crypto_tx_common(const char* name, const char* config_file)
    : m_parms(new tx_parms())
{
    unsigned char  key[FREEDV_MASTER_KEY_LENGTH];
    unsigned char  iv[IV_LEN];

    m_parms->cur = static_cast<struct config*>(calloc(1, sizeof(struct config)));
    read_config(config_file, m_parms->cur);

    string config_file_name(m_parms->cur->log_file);
    size_t name_idx = config_file_name.find("{name}");
    if (name_idx != string::npos)
    {
        config_file_name.replace(name_idx, 6, name);
    }

    m_parms->logger = create_logger(config_file_name.c_str(),
                                    m_parms->cur->log_level);

    if (m_parms->cur->freedv_enabled)
    {
        m_parms->freedv = freedv_open(m_parms->cur->freedv_mode);
        if (m_parms->freedv == NULL) {
            log_message(m_parms->logger, LOG_ERROR, "Could not initialize voice modulator");
        }
    }

    if (m_parms->freedv != nullptr)
    {
        // Use getrandom with the urandom device because it will block until the
        // entropy pool is initialized
        if (getrandom(iv, sizeof(iv), 0) != sizeof(iv)) {
            log_message(m_parms->logger, LOG_WARN, "Did not fully read initialization vector");
        }
        else {
            log_message(m_parms->logger, LOG_INFO, "Read initialization vector");
        }

        const size_t key_bytes_read = read_key_file(m_parms->cur->key_file, key);
        if (str_has_value(m_parms->cur->key_file) &&
            key_bytes_read != FREEDV_MASTER_KEY_LENGTH)
        {
            log_message(m_parms->logger,
                        LOG_WARN,
                        "Truncated encryption key: Only %d bytes of a possible %d",
                        (int)key_bytes_read,
                        (int)FREEDV_MASTER_KEY_LENGTH);
        }

        if (str_has_value(m_parms->cur->key_file) && m_parms->cur->crypto_enabled) {
            freedv_set_crypto(m_parms->freedv, key, iv);
        }
        else {
            log_message(m_parms->logger, LOG_WARN, "Encryption disabled");
        }

        configure_freedv(m_parms->freedv, m_parms->cur);
    }
}

bool crypto_tx_common::using_freedv() const
{
    return m_parms->freedv != nullptr;
}

size_t crypto_tx_common::speech_samples_per_frame() const
{
    if (using_freedv())
    {
        return static_cast<size_t>(freedv_get_n_speech_samples(m_parms->freedv));
    }
    else
    {
        return ANALOG_SAMPLES_PER_FRAME;
    }
}

uint crypto_tx_common::speech_sample_rate() const
{
    if (using_freedv())
    {
        return freedv_get_speech_sample_rate(m_parms->freedv);
    }
    else
    {
        return ANALOG_SAMPLE_RATE;
    }
}

size_t crypto_tx_common::modem_samples_per_frame() const
{
    if (using_freedv())
    {
        return static_cast<size_t>(freedv_get_n_nom_modem_samples(m_parms->freedv));
    }
    else
    {
        return ANALOG_SAMPLES_PER_FRAME;
    }
}

uint crypto_tx_common::modem_sample_rate() const
{
    if (using_freedv())
    {
        return freedv_get_modem_sample_rate(m_parms->freedv);
    }
    else
    {
        return ANALOG_SAMPLE_RATE;
    }
}

const struct config* crypto_tx_common::get_config() const
{
    return m_parms->cur;
}

void crypto_tx_common::log_to_logger(int level, const char* msg)
{
    log_message(m_parms->logger, level, "%s", msg);
}

void crypto_tx_common::force_rekey_next_frame()
{
    m_parms->force_rekey = true;
}

size_t crypto_tx_common::transmit(short* mod_out, const short* speech_in)
{
    const int n_speech_samples = speech_samples_per_frame();
    const int n_nom_modem_samples = modem_samples_per_frame();
    const int speech_samples_per_second = speech_sample_rate();
    const int speech_frames_per_second = speech_samples_per_second / n_speech_samples;

    if (using_freedv() &&
        str_has_value(m_parms->cur->key_file) &&
        m_parms->cur->crypto_enabled)
    {
        ++m_parms->frames_since_rekey;

        bool reset_iv = m_parms->force_rekey;
        // Reset IV at regular intervals (if configured)
        const int rekey_frames = speech_frames_per_second *
                                 m_parms->cur->rekey_period;
        if (rekey_frames > 0 && (m_parms->frames_since_rekey % rekey_frames) == 0)
        {
            log_message(m_parms->logger,
                        LOG_INFO,
                        "New initialization vector due to auto rekey");
            reset_iv = true;
        }

        if (reset_iv)
        {
            m_parms->force_rekey = false;
            m_parms->frames_since_rekey = 0;

            unsigned char iv[IV_LEN];
            // Use getrandom with the urandom device because it will block
            // until the entropy pool is initialized
            if (getrandom(iv, sizeof(iv), 0) != sizeof(iv)) {
                log_message(m_parms->logger,
                            LOG_WARN,
                            "Did not fully read initialization vector");
            }
            else {
                log_message(m_parms->logger,
                            LOG_INFO,
                            "Read initialization vector");
            }

            freedv_set_crypto(m_parms->freedv, NULL, iv);
        }
    }

    if (using_freedv())
    {
        freedv_tx(m_parms->freedv, mod_out, const_cast<short*>(speech_in));
    }
    else
    {
        memcpy(mod_out, speech_in, n_speech_samples * sizeof(short));
    }

    return n_nom_modem_samples;
}

HCRYPTO_TX* crypto_tx_create(const char* name, const char* config_file_path)
{
    try
    {
        return reinterpret_cast<HCRYPTO_TX*>(new crypto_tx_common(name, config_file_path));
    }
    catch(...)
    {
        return NULL;
    }
}

void crypto_tx_destroy(HCRYPTO_TX* hnd)
{
    delete reinterpret_cast<crypto_tx_common*>(hnd);
}

int crypto_tx_speech_samples_per_frame(HCRYPTO_TX* hnd)
{
    return reinterpret_cast<crypto_tx_common*>(hnd)->speech_samples_per_frame();
}

int crypto_tx_modem_samples_per_frame(HCRYPTO_TX* hnd)
{
    return reinterpret_cast<crypto_tx_common*>(hnd)->modem_samples_per_frame();
}

const struct config* crypto_tx_get_config(HCRYPTO_TX* hnd)
{
    return reinterpret_cast<crypto_tx_common*>(hnd)->get_config();
}

void crypto_tx_log_to_logger(HCRYPTO_TX* hnd, int level, const char* msg)
{
    return reinterpret_cast<crypto_tx_common*>(hnd)->log_to_logger(level, msg);
}

int crypto_tx_transmit(HCRYPTO_TX* hnd, short* mod_out, const short* speech_in)
{
    try
    {
        return reinterpret_cast<crypto_tx_common*>(hnd)->transmit(mod_out, speech_in);
    }
    catch(...)
    {
        return -1;
    }
}

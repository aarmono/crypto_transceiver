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
        if (old != nullptr) free(old);
        if (cur != nullptr) free(cur);
        if (urandom != nullptr) fclose(urandom);
        if (freedv != nullptr) freedv_close(freedv);
        destroy_logger(logger);
    }

    struct config* old = nullptr;
    struct config* cur = nullptr;
    FILE*          urandom = nullptr;
    struct freedv* freedv = nullptr;
    crypto_log     logger;
    unsigned short silent_frames = 0;
};

crypto_tx_common::~crypto_tx_common() {}

crypto_tx_common::crypto_tx_common(const char* config_file)
    : m_parms(new tx_parms())
{
    unsigned char  key[FREEDV_MASTER_KEY_LENGTH];
    unsigned char  iv[IV_LEN];

    m_parms->cur = static_cast<struct config*>(calloc(1, sizeof(struct config)));
    read_config(config_file, m_parms->cur);

    m_parms->logger = create_logger(m_parms->cur->log_file,
                                    m_parms->cur->log_level);

    open_iv_file(m_parms->old, m_parms->cur, &m_parms->urandom);
    if (m_parms->urandom == NULL) {
        log_message(m_parms->logger,
                    LOG_ERROR,
                    "Unable to open random number generator: %s",
                    m_parms->cur->random_file);
        throw std::runtime_error("Unable to open random number generator");
    }

    if (fread(iv, 1, sizeof(iv), m_parms->urandom) != sizeof(iv)) {
        log_message(m_parms->logger, LOG_WARN, "Did not fully read initialization vector");
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

    m_parms->freedv = freedv_open(m_parms->cur->freedv_mode);
    if (m_parms->freedv == NULL) {
        log_message(m_parms->logger, LOG_ERROR, "Could not initialize voice modulator");
        throw std::runtime_error("Could not initialize voice modulator");
    }

    if (str_has_value(m_parms->cur->key_file)) {
        freedv_set_crypto(m_parms->freedv, key, iv);
    }
    else {
        log_message(m_parms->logger, LOG_WARN, "Encryption disabled");
    }

    configure_freedv(m_parms->freedv);
}

size_t crypto_tx_common::speech_samples_per_frame() const
{
    return static_cast<size_t>(freedv_get_n_speech_samples(m_parms->freedv));
}

uint crypto_tx_common::speech_sample_rate() const
{
    return freedv_get_speech_sample_rate(m_parms->freedv);
}

size_t crypto_tx_common::modem_samples_per_frame() const
{
    return static_cast<size_t>(freedv_get_n_nom_modem_samples(m_parms->freedv));
}

uint crypto_tx_common::modem_sample_rate() const
{
    return freedv_get_modem_sample_rate(m_parms->freedv);
}

const struct config* crypto_tx_common::get_config() const
{
    return m_parms->cur;
}

void crypto_tx_common::log_to_logger(int level, const char* msg)
{
    log_message(m_parms->logger, level, "%s", msg);
}

bool crypto_tx_common::transmit(short* mod_out, const short* speech_in)
{
    bool reset_iv = false;
    const int n_speech_samples = freedv_get_n_speech_samples(m_parms->freedv);
    const int n_nom_modem_samples = freedv_get_n_nom_modem_samples(m_parms->freedv);
    const int speech_samples_per_second = freedv_get_speech_sample_rate(m_parms->freedv);
    const int speech_frames_per_second = speech_samples_per_second / n_speech_samples;
    unsigned char iv[IV_LEN];

    if (str_has_value(m_parms->cur->key_file) &&
        m_parms->cur->vox_low > 0 && m_parms->cur->vox_high > 0)
    {
        const short rms_val = rms(speech_in, n_speech_samples);
        log_message(m_parms->logger, LOG_DEBUG, "Voice RMS: %d", (int)rms_val);

        if (rms_val > m_parms->cur->vox_high && m_parms->silent_frames > 0) {
            log_message(m_parms->logger,
                        LOG_INFO,
                        "Voice detected. RMS: %d",
                        (int)rms_val);
            m_parms->silent_frames = 0;
        }
        /* If a frame drops below iv_low or is between iv_low and iv_high after
           dropping below iv_low, increment the silent counter */
        else if (rms_val < m_parms->cur->vox_low || m_parms->silent_frames > 0) {
            ++m_parms->silent_frames;
            log_message(m_parms->logger,
                        LOG_DEBUG,
                        "Quiet frame. Count: %d",
                        (int)m_parms->silent_frames);

            const int vox_reset_frames = speech_frames_per_second *
                                         m_parms->cur->vox_period;
            if (m_parms->cur->vox_period > 0 &&
                (m_parms->silent_frames == vox_reset_frames)) {
                log_message(m_parms->logger,
                            LOG_INFO,
                            "New initialization vector at end of voice. RMS: %d",
                            (int)rms_val);
                reset_iv = true;
            }

            /* Reset IV every minute of silence (if configured)*/
            const int silent_reset_frames = speech_frames_per_second *
                                            m_parms->cur->silent_period;
            if (m_parms->cur->silent_period > 0 &&
                (m_parms->silent_frames % silent_reset_frames) == 0) {
                log_message(m_parms->logger,
                            LOG_INFO,
                            "New initialization vector during long silence. RMS: %d",
                            (int)rms_val);
                reset_iv = true;
            }
        }

        if (reset_iv) {
            if (fread(iv, 1, sizeof(iv), m_parms->urandom) != sizeof(iv)) {
                log_message(m_parms->logger,
                            LOG_WARN,
                            "Did not fully read initialization vector");
            }

            freedv_set_crypto(m_parms->freedv, NULL, iv);
        }
    }

    freedv_tx(m_parms->freedv, mod_out, const_cast<short*>(speech_in));

    return reset_iv;
}

HCRYPTO_TX* crypto_tx_create(const char* config_file_path)
{
    try
    {
        return reinterpret_cast<HCRYPTO_TX*>(new crypto_tx_common(config_file_path));
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

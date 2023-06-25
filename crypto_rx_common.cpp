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

#include "crypto_common.h"
#include "crypto_rx_common.h"

using namespace std;

struct crypto_rx_common::rx_parms
{
    rx_parms(const char* cfg)
        : config_file(cfg)
    {
        memset(&logger, 0, sizeof(logger));
    }
    ~rx_parms()
    {
        if (cur != nullptr) free(cur);
        if (freedv != nullptr) freedv_close(freedv);
        destroy_logger(logger);
    }

    const string      config_file;
    struct config*    cur = nullptr;
    struct freedv*    freedv = nullptr;
    crypto_log        logger;
    unsigned short    silent_frames = 0;
    encryption_status crypto_status = CRYPTO_STATUS_PLAIN;
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

    if (str_has_value(m_parms->cur->key_file) && m_parms->cur->crypto_enabled) {
        freedv_set_crypto(m_parms->freedv, key, iv);
        m_parms->crypto_status = key_bytes_read == FREEDV_MASTER_KEY_LENGTH ?
            CRYPTO_STATUS_ENCRYPTED : CRYPTO_STATUS_WEAK_KEY;
    }
    else {
        m_parms->crypto_status = CRYPTO_STATUS_PLAIN;
        log_message(m_parms->logger, LOG_WARN, "Encryption disabled");
    }

    m_parms->silent_frames = modem_frames_per_second();
}

size_t crypto_rx_common::max_speech_samples_per_frame() const
{
    return freedv_get_n_max_speech_samples(m_parms->freedv);
}

size_t crypto_rx_common::max_modem_samples_per_frame() const
{
    return freedv_get_n_max_modem_samples(m_parms->freedv);
}

size_t crypto_rx_common::modem_samples_per_frame() const
{
    return static_cast<size_t>(freedv_get_n_nom_modem_samples(m_parms->freedv));
}

size_t crypto_rx_common::needed_modem_samples() const
{
    return freedv_nin(m_parms->freedv);
}

bool crypto_rx_common::is_synced() const
{
    return (freedv_get_rx_status(m_parms->freedv) & FREEDV_RX_SYNC) != 0;
}

encryption_status crypto_rx_common::get_encryption_status() const
{
    return m_parms->crypto_status;
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

int crypto_rx_common::modem_frames_per_second() const
{
    return freedv_get_modem_sample_rate(m_parms->freedv) /
           freedv_get_n_nom_modem_samples(m_parms->freedv);
}

size_t crypto_rx_common::receive(short* speech_out, short* demod_in)
{
    const int nin = freedv_nin(m_parms->freedv);
    const size_t nout = freedv_rx(m_parms->freedv, speech_out, demod_in);

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

int crypto_rx_receive(HCRYPTO_RX* hnd, short* speech_out, short* demod_in)
{
    return reinterpret_cast<crypto_rx_common*>(hnd)->receive(speech_out, demod_in);
}

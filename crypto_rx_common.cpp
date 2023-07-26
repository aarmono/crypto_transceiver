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
    encryption_status crypto_status = CRYPTO_STATUS_PLAIN;
    bool              modem_has_signal = false;
    int               modem_flush_frames = 0;
};

crypto_rx_common::~crypto_rx_common() {}

crypto_rx_common::crypto_rx_common(const char* name, const char* config_file)
    : m_parms(new rx_parms(config_file))
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

    if (m_parms->cur->freedv_enabled != 0)
    {
        m_parms->freedv = freedv_open(m_parms->cur->freedv_mode);
        if (m_parms->freedv == NULL) {
            log_message(m_parms->logger, LOG_ERROR, "Could not initialize voice demodulator");
        }
    }

    if (m_parms->freedv != nullptr)
    {
        size_t key_bytes_read = read_key_file(m_parms->cur->key_file, key);
        if (str_has_value(m_parms->cur->key_file) &&
            key_bytes_read != FREEDV_MASTER_KEY_LENGTH) {
            log_message(m_parms->logger,
                        LOG_WARN,
                        "Truncated decryption key: Only %d bytes of a possible %d",
                        (int)key_bytes_read,
                        (int)FREEDV_MASTER_KEY_LENGTH);
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

        configure_freedv(m_parms->freedv, m_parms->cur);
    }
    else
    {
        m_parms->crypto_status = CRYPTO_STATUS_PLAIN;
    }

    m_parms->modem_flush_frames = m_parms->cur->modem_num_quiet_flush_frames;
}

bool crypto_rx_common::using_freedv() const
{
    return m_parms->freedv != nullptr;
}

size_t crypto_rx_common::max_speech_samples_per_frame() const
{
    if (using_freedv())
    {
        return freedv_get_n_max_speech_samples(m_parms->freedv);
    }
    else
    {
        return ANALOG_SAMPLES_PER_FRAME;
    }
}

size_t crypto_rx_common::speech_samples_per_frame() const
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

size_t crypto_rx_common::max_modem_samples_per_frame() const
{
    if (using_freedv())
    {
        return freedv_get_n_max_modem_samples(m_parms->freedv);
    }
    else
    {
        return ANALOG_SAMPLES_PER_FRAME;
    }
}

size_t crypto_rx_common::modem_samples_per_frame() const
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

size_t crypto_rx_common::needed_modem_samples() const
{
    if (using_freedv())
    {
        return freedv_nin(m_parms->freedv);
    }
    else
    {
        return ANALOG_SAMPLES_PER_FRAME;
    }
}

bool crypto_rx_common::is_synced() const
{
    if (using_freedv())
    {
        return (freedv_get_rx_status(m_parms->freedv) & FREEDV_RX_SYNC) != 0;
    }
    else
    {
        return true;
    }
}

encryption_status crypto_rx_common::get_encryption_status() const
{
    return m_parms->crypto_status;
}

uint crypto_rx_common::speech_sample_rate() const
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

uint crypto_rx_common::modem_sample_rate() const
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
    return modem_sample_rate() / modem_samples_per_frame();
}

size_t crypto_rx_common::receive(short* speech_out, const short* demod_in)
{
    const int nin = needed_modem_samples();
    size_t nout = 0;

    if (using_freedv())
    {
        // Only do the modem squelch when using digital
        const short modem_rms = rms(demod_in, nin);

        // RMS-based modem squelch with hysteresis. The built in squelch
        // in FreeDV (especially with the 2400B mode) can sometimes fail at very
        // low input signal levels because the modem reports a very high estimated
        // SNR
        // A nin of zero is apparently valid, and if it is we need to force
        // the freedv_rx call
        if (nin == 0)
        {
            m_parms->modem_has_signal = true;
        }
        else if (modem_rms < m_parms->cur->modem_quiet_max_thresh)
        {
            m_parms->modem_has_signal = false;
        }
        else if (modem_rms >= m_parms->cur->modem_signal_min_thresh)
        {
            m_parms->modem_has_signal = true;
        }

        if (m_parms->modem_has_signal)
        {
            m_parms->modem_flush_frames = 0;
        }
        else if (m_parms->modem_flush_frames <=
                 m_parms->cur->modem_num_quiet_flush_frames)
        {
            ++m_parms->modem_flush_frames;
        }

        // Only call freedv_rx if there is signal or for the first few
        // "silent" frames to flush out the system
        if (m_parms->modem_has_signal == true ||
            m_parms->modem_flush_frames <= m_parms->cur->modem_num_quiet_flush_frames)
        {
            nout = freedv_rx(m_parms->freedv, speech_out, const_cast<short*>(demod_in));
            if (m_parms->modem_has_signal == false && nout > 0)
            {
                // If we are flushing frames, Call freedv_rx but discard the output
                zeroize_frames(speech_out, nout);
            }

            float snr_est = 0.0;
            freedv_get_modem_stats(m_parms->freedv, nullptr, &snr_est);
            log_message(m_parms->logger,
                        LOG_DEBUG,
                        "nout: %u, SNR est.: %f, modem RMS: %d",
                        (uint)nout,
                        snr_est,
                        (int)modem_rms);
        }
        // When the transition from "signal" to "no signal" occurs, signal the modem
        // needs to resync when the signal returns. Do this at the start of
        // "loss of signal" instead of the beginning of "acquisition of signal" to
        // ensure freedv functions called after the last call to receive and during
        // this one are on a consistent state of the freedv object
        else
        {
            freedv_set_sync(m_parms->freedv, FREEDV_SYNC_UNSYNC);
        }
    }
    else
    {
        memcpy(speech_out, demod_in, nin * sizeof(short));
        nout = nin;
    }

    return nout;
}

HCRYPTO_RX* crypto_rx_create(const char* name, const char* config_file_path)
{
    try
    {
        return reinterpret_cast<HCRYPTO_RX*>(new crypto_rx_common(name, config_file_path));
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

int crypto_rx_receive(HCRYPTO_RX* hnd, short* speech_out, const short* demod_in)
{
    return reinterpret_cast<crypto_rx_common*>(hnd)->receive(speech_out, demod_in);
}

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

#include <sndfile.h>
#include <freedv_api.h>

#include "crypto_cfg.h"
#include "resampler.h"
#include "jack_common.h"

bool read_wav_file(const char*     filepath,
                   jack_nframes_t  jack_sample_rate,
                   audio_buffer_t& buffer_out)
{
    SF_INFO sfinfo;
    memset (&sfinfo, 0, sizeof (sfinfo));

    SNDFILE* infile = sf_open (filepath, SFM_READ, &sfinfo);
    if (infile == nullptr)
    {
        return false;
    }

    if (sfinfo.channels != 1)
    {
        return false;
    }

    const size_t block_len = 1024;
    audio_buffer_t buffer(block_len);
    sf_count_t readcount = 0;
    while ((readcount = sf_readf_float(infile,
                                       (buffer.data() + buffer.size()) - block_len,
                                       block_len)) == block_len)
    {
        buffer.resize(buffer.size() + block_len);
    }

    size_t toremove = block_len - readcount;
    buffer.erase(buffer.cend() - toremove, buffer.cend());

    sf_close (infile);

    if (sfinfo.samplerate != jack_sample_rate)
    {
        const size_t max_resample_frames =
            get_max_resampled_frames(buffer.size(), sfinfo.samplerate, jack_sample_rate);
        audio_buffer_t resample_buffer(max_resample_frames);

        const size_t resample_frames =
            resample_complete_buffer(SRC_SINC_FASTEST, 1,
                                     buffer.data(),
                                     buffer.size(),
                                     sfinfo.samplerate,
                                     resample_buffer.data(),
                                     max_resample_frames,
                                     jack_sample_rate);

        resample_buffer.resize(resample_frames);
        std::swap(buffer, resample_buffer);
    }


    std::swap(buffer_out, buffer);

    return true;
}

int get_jack_period(const struct config* cfg)
{
    switch(cfg->freedv_mode)
    {
        case FREEDV_MODE_700C:
            return cfg->jack_rx_period_700c;
        case FREEDV_MODE_700D:
            return cfg->jack_rx_period_700d;
        case FREEDV_MODE_700E:
            return cfg->jack_rx_period_700e;
        case FREEDV_MODE_800XA:
            return cfg->jack_rx_period_800xa;
        case FREEDV_MODE_1600:
            return cfg->jack_rx_period_1600;
        case FREEDV_MODE_2400B:
            return cfg->jack_rx_period_2400b;
        default:
            return 0;
    }
}

bool connect_input_ports(jack_client_t* client,
                         jack_port_t*   output_port,
                         const char*    input_port_regex)
{
    const char** playback_ports = jack_get_ports(client,
                                                 input_port_regex,
                                                 NULL,
                                                 JackPortIsInput);
    if (playback_ports != NULL && *playback_ports != NULL)
    {
        const char* out_port_name = jack_port_name(output_port);
        for (size_t i = 0; playback_ports[i] != NULL; ++i)
        {
            if (jack_connect(client, out_port_name, playback_ports[i]) != 0)
            {
                fprintf(stderr,
                        "Could not connect %s port to %s port\n",
                        out_port_name,
                        playback_ports[i]);
                jack_free(playback_ports);
                return false;
            }
        }

        jack_free(playback_ports);
        return true;
    }
    else
    {
        fprintf(stderr, "Could not find ports matching %s\n", input_port_regex);
        if (playback_ports != NULL) jack_free(playback_ports);
        return false;
    }
}


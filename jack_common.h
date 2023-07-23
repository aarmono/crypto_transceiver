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

#ifndef JACK_COMMON_H
#define JACK_COMMON_H

#include <vector>

#include <jack/jack.h>

struct config;
typedef std::vector<jack_default_audio_sample_t> audio_buffer_t;

int get_jack_period(const struct config* cfg);

bool connect_input_ports(jack_client_t* client,
                         jack_port_t*   output_port,
                         const char*    input_port_regex);

bool read_wav_file(const char*     filepath,
                   jack_nframes_t  jack_sample_rate,
                   audio_buffer_t& buffer_out);

#endif

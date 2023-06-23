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

#include <stdio.h>
#include <signal.h>
#include <sys/wait.h>
#include <unistd.h>

#include <vector>
#include <memory>

#include <jack/jack.h>

#include "resampler.h"
#include "crypto_cfg.h"
#include "crypto_tx_common.h"

static std::unique_ptr<crypto_tx_common> crypto_tx;

static jack_port_t* voice_port = NULL;
static jack_port_t* modem_port = NULL;
static jack_client_t* client = NULL;

static std::unique_ptr<resampler> input_resampler;
static std::unique_ptr<resampler> output_resampler;

static volatile sig_atomic_t reload_config = 0;

static void signal_handler(int sig)
{
    jack_client_close(client);
    fprintf(stderr, "signal received, exiting ...\n");
    exit(0);
}

static void handle_sighup(int sig)
{
    reload_config = 1;
}

/**
 * JACK calls this shutdown_callback if the server ever shuts down or
 * decides to disconnect the client.
 */
void jack_shutdown(void *arg)
{
    exit (1);
}

/**
 * The process callback for this JACK application is called in a
 * special realtime thread once for each audio cycle.
 *
 * This client follows a simple rule: when the JACK transport is
 * running, copy the input port to the output.  When it stops, exit.
 */
int process(jack_nframes_t nframes, void *arg)
{
    jack_default_audio_sample_t* voice_frames =
        (jack_default_audio_sample_t*)jack_port_get_buffer(voice_port, nframes);

    const jack_nframes_t jack_sample_rate = jack_get_sample_rate(client);
    const uint voice_sample_rate = crypto_tx->speech_sample_rate();
    const uint modem_sample_rate = crypto_tx->modem_sample_rate();

    input_resampler->set_sample_rates(jack_sample_rate, voice_sample_rate);
    output_resampler->set_sample_rates(modem_sample_rate, jack_sample_rate);

    input_resampler->enqueue(voice_frames, nframes);

    int n_nom_modem_samples = crypto_tx->modem_samples_per_frame();
    int n_speech_samples = crypto_tx->speech_samples_per_frame();
    while (input_resampler->available_elems() >= n_speech_samples)
    {
        short mod_out[n_nom_modem_samples];
        short voice_in[n_speech_samples];
        input_resampler->dequeue(voice_in, n_speech_samples);

        const bool reload_config_this_loop = reload_config;
        crypto_tx->transmit(mod_out, voice_in, reload_config_this_loop);

        output_resampler->enqueue(mod_out, n_nom_modem_samples);

        if (reload_config_this_loop) {
            reload_config = 0;

            // In case the mode changed
            n_nom_modem_samples = crypto_tx->modem_samples_per_frame();
            n_speech_samples = crypto_tx->speech_samples_per_frame();
        }
    }

    if (output_resampler->available_elems() >= nframes)
    {
        jack_default_audio_sample_t* modem_frames =
            (jack_default_audio_sample_t*)jack_port_get_buffer(modem_port, nframes);
        output_resampler->dequeue(modem_frames, nframes);
    }

    return 0;
}

int main(int argc, char *argv[])
{
    const char* client_name = "crypto_tx";
    const char* server_name = nullptr;
    const char* config_file = nullptr;
    jack_options_t options = JackNullOption;
    jack_status_t status;

    struct config *cur = NULL;

    if (argc > 2)
    {
        server_name = argv[1];
        options = (jack_options_t)(JackNullOption | JackServerName);

        config_file = argv[2];
    }
    else
    {
        fprintf(stderr, "Usage: crypto_tx <jack server name> <config file>");
        exit(1);
    }

    fprintf(stderr, "Server name: %s\n", server_name ? server_name : "");

    try
    {
        input_resampler.reset(new resampler(SRC_SINC_FASTEST, 1));
        output_resampler.reset(new resampler(SRC_SINC_FASTEST, 1));
        crypto_tx.reset(new crypto_tx_common(config_file));
    }
    catch (const std::exception& ex)
    {
        fprintf(stderr, "%s", ex.what());
        exit(1);
    }

    /* open a client connection to the JACK server */

    client = jack_client_open (client_name, options, &status, server_name);
    if (client == NULL)
    {
        fprintf (stderr,
                 "jack_client_open() failed, "
                 "status = 0x%2.0x\n",
                 status);
        if (status & JackServerFailed)
        {
            fprintf (stderr, "Unable to connect to JACK server\n");
        }
        exit (1);
    }
    if (status & JackServerStarted)
    {
        fprintf (stderr, "JACK server started\n");
    }
    if (status & JackNameNotUnique)
    {
        client_name = jack_get_client_name(client);
        fprintf (stderr, "unique name `%s' assigned\n", client_name);
    }

    const struct config* cfg = crypto_tx->get_config();
    const jack_nframes_t period = get_jack_period(cfg);
    jack_set_buffer_size(client, period);

    /* tell the JACK server to call `process()' whenever
       there is work to be done.
    */
    jack_set_process_callback (client, process, nullptr);

    /* tell the JACK server to call `jack_shutdown()' if
       it ever shuts down, either entirely, or if it
       just decides to stop calling us.
    */
    jack_on_shutdown (client, jack_shutdown, 0);

    /* create two ports */
    voice_port = jack_port_register(client,
                                    "voice_in",
                                    JACK_DEFAULT_AUDIO_TYPE,
                                    JackPortIsInput,
                                    0);

    modem_port = jack_port_register(client,
                                    "modem_out",
                                    JACK_DEFAULT_AUDIO_TYPE,
                                    JackPortIsOutput,
                                    0);

    if ((voice_port == NULL) || (modem_port == NULL))
    {
        fprintf(stderr, "no more JACK ports available\n");
        exit (1);
    }

    /* Tell the JACK server that we are ready to roll.  Our
     * process() callback will start running now. */
    if (jack_activate (client))
    {
        fprintf (stderr, "cannot activate client");
        exit (1);
    }

    signal(SIGQUIT, signal_handler);
    signal(SIGTERM, signal_handler);
    signal(SIGHUP, handle_sighup);
    signal(SIGINT, signal_handler);

    while (true)
    {
        sleep(1);
    }
    
    jack_client_close (client);
    return 0;
}


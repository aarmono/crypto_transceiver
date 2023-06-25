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

static jack_port_t* voice_port = nullptr;
static jack_port_t* modem_port = nullptr;
static jack_client_t* client = nullptr;

static std::unique_ptr<resampler> input_resampler;
static std::unique_ptr<resampler> output_resampler;

static volatile sig_atomic_t reload_config = 0;

static const char* config_file = nullptr;

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

    const int n_nom_modem_samples = crypto_tx->modem_samples_per_frame();
    const int n_speech_samples = crypto_tx->speech_samples_per_frame();
    while (input_resampler->available_elems() >= n_speech_samples)
    {
        short mod_out[n_nom_modem_samples];
        short voice_in[n_speech_samples];
        input_resampler->dequeue(voice_in, n_speech_samples);

        crypto_tx->transmit(mod_out, voice_in);

        output_resampler->enqueue(mod_out, n_nom_modem_samples);
    }

    if (output_resampler->available_elems() >= nframes)
    {
        jack_default_audio_sample_t* modem_frames =
            (jack_default_audio_sample_t*)jack_port_get_buffer(modem_port, nframes);
        output_resampler->dequeue(modem_frames, nframes);
    }

    return 0;
}

static bool connect_input_ports(jack_port_t* output_port,
                                const char* input_port_regex)
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

static void activate_client()
{
    const struct config* cfg = crypto_tx->get_config();
    const jack_nframes_t period = get_jack_period(cfg);
    jack_set_buffer_size(client, period);

    /* Tell the JACK server that we are ready to roll.  Our
     * process() callback will start running now. */
    if (jack_activate (client))
    {
        fprintf (stderr, "cannot activate client");
        exit (1);
    }

    /* Get the port from which we will get data */
    const char* capture_port_name =
        *cfg->jack_voice_in_port ? cfg->jack_voice_in_port : "system:capture_1";
    if (jack_connect(client, capture_port_name, jack_port_name(voice_port)) != 0)
    {
        fprintf(stderr, "Could not connect modem port");
        exit (1);
    }

    const char* playback_port_regex =
        *cfg->jack_modem_out_port ? cfg->jack_modem_out_port : "system:playback_*";
    if (!connect_input_ports(modem_port, playback_port_regex))
    {
        exit(1);
    }
}

static void initialize_crypto()
{
    crypto_tx = nullptr;
    input_resampler = nullptr;
    output_resampler = nullptr;

    crypto_tx.reset(new crypto_tx_common(config_file));

    const size_t speech_frames =
        get_max_resampled_frames(crypto_tx->speech_samples_per_frame(),
                                 crypto_tx->speech_sample_rate(),
                                 jack_get_sample_rate(client));
    const size_t modem_frames =
        get_max_resampled_frames(crypto_tx->modem_samples_per_frame(),
                                 crypto_tx->modem_sample_rate(),
                                 jack_get_sample_rate(client));

    input_resampler.reset(new resampler(SRC_SINC_FASTEST, 1, speech_frames * 2));
    output_resampler.reset(new resampler(SRC_SINC_FASTEST, 1, modem_frames * 2));
}

int main(int argc, char *argv[])
{
    const char* client_name = "crypto_tx";
    const char* server_name = nullptr;
    jack_options_t options = JackNullOption;
    jack_status_t status;

    struct config *cur = NULL;

    if (argc > 2)
    {
        server_name = argv[1];
        options = (jack_options_t)(JackNullOption | JackServerName | JackNoStartServer);

        config_file = argv[2];
    }
    else
    {
        fprintf(stderr, "Usage: jack_crypto_tx <jack server name> <config file>");
        exit(1);
    }

    fprintf(stderr, "Server name: %s\n", server_name ? server_name : "");

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

    try
    {
        initialize_crypto();
    }
    catch (const std::exception& ex)
    {
        fprintf(stderr, "%s", ex.what());
        exit(1);
    }

    activate_client();

    signal(SIGQUIT, signal_handler);
    signal(SIGTERM, signal_handler);
    signal(SIGHUP, handle_sighup);
    signal(SIGINT, signal_handler);

    while (true)
    {
        if (reload_config != 0) {
            reload_config = 0;

            jack_deactivate(client);
            crypto_tx = nullptr;
            try
            {
                initialize_crypto();
            }
            catch (const std::exception& ex)
            {
                fprintf(stderr, "%s", ex.what());
                exit(1);
            }
            activate_client();
        }
        sleep(1);
    }
    
    jack_client_close (client);
    return 0;
}


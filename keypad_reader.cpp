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

#include <sys/types.h>
#include <sys/time.h>
#include <signal.h>
#include <unistd.h>
#include <time.h>

#include <cstdlib>
#include <cstdint>
#include <cstdio>
#include <cstring>

#include <vector>
#include <memory>

#include <gpiod.h>

#include "crypto_cfg.h"
#include "debounce.h"

enum key_state_t
{
    STATE_RESET,

    STATE_A_SELECT,
    STATE_A_VALUE,
    STATE_A_UPDATE,
    STATE_A_INCR,

    STATE_B_SELECT,
    STATE_B_VALUE,
    STATE_B_UPDATE,
    STATE_B_INCR
};

static const char* BUTTON_A = "a";
static const char* BUTTON_B = "b";
static const char* BUTTON_D = "d";
static const char* BUTTON_UP = "up";
static const char* BUTTON_DOWN = "down";

static const char* EVENT_ALERT = "alert";
static const char* EVENT_RESET = "reset";
static const char* EVENT_SELECT = "select";
static const char* EVENT_VALUE = "value";
static const char* EVENT_UPDATE = "update";
static const char* EVENT_INCR = "incr";

#define NUM_LINES 5

#define A_OFF    0
#define B_OFF    1
#define D_OFF    2
#define UP_OFF   3
#define DOWN_OFF 4

struct signal_state_t
{
    struct gpiod_line_bulk lines = GPIOD_LINE_BULK_INITIALIZER;

    int update_fd = 0;

    std::vector<debounce> debouncers;

    uint8_t alert_counter = 0;
    uint8_t alert_val = 0;
    float   alert_time = 0.0;

    int prev_d_val = 0;

    uint8_t prev_vol_val = 0;

    key_state_t cur_state = STATE_RESET;

    signal_state_t(unsigned int integrator)
        : debouncers(NUM_LINES, integrator)
    {
    }
};

std::unique_ptr<signal_state_t> signal_state;

static volatile sig_atomic_t read_io = 0;

int get_lines(unsigned int            a_pin,
              unsigned int            b_pin,
              unsigned int            d_pin,
              unsigned int            up_pin,
              unsigned int            down_pin,
              const char*             bias,
              const char*             active_low,
              struct gpiod_line_bulk* lines)
{
    unsigned int offsets[NUM_LINES] = { a_pin, b_pin, d_pin, up_pin, down_pin };

    struct gpiod_chip* chip = gpiod_chip_open_lookup("gpiochip0");
    if (chip == nullptr)
    {
        return -1;
    }

    int ret = gpiod_chip_get_lines(chip, offsets, NUM_LINES, lines);
    if (ret < 0)
    {
        return ret;
    }

    const int flags = bias_flags(bias) | active_flags(active_low);
    ret = gpiod_line_request_bulk_input_flags(lines, "keypad", flags);
    return ret;
}

float get_cur_time()
{
    struct timespec cur_time;
    clock_gettime(CLOCK_MONOTONIC_COARSE, &cur_time);

    return (cur_time.tv_nsec * .000000001) + cur_time.tv_sec;
}

int run_keypad_updater()
{
    int fds[2] = {0, 0};
    pipe(fds);

    if (fork() == 0)
    {
        // Close writing end
        close(fds[1]);
        // Map reading end to stdin
        dup2(fds[0], 0);
        // Now close reading end
        close(fds[0]);

        execl("/usr/bin/keypad_updater.sh", "keypad_updater.sh", (char*)NULL);
        return 0;
    }
    else
    {
        // Close reading end
        close(fds[0]);
        // Return writing end
        return fds[1];
    }
}

void send_keypad_update(int fd, const char* button, const char* event)
{
    char buf[80];

    char* ptr = stpcpy(buf, button);
    ptr = stpcpy(ptr, " ");
    ptr = stpcpy(ptr, event);
    ptr = stpcpy(ptr, "\n");

    const size_t len = ptr - buf;
    write(fd, buf, len);
}

void sample_tick()
{
    int values[NUM_LINES] = {0,};
    if (gpiod_line_get_value_bulk(&signal_state->lines, values) < 0)
    {
        fprintf(stderr, "Error reading lines\n");
    }

    for (uint i = 0; i < NUM_LINES; ++i)
    {
        values[i] = static_cast<int>(signal_state->debouncers[i].add_value(values[i]));
    }

    const uint8_t cur_vol_val =
        (values[UP_OFF] << 0) | (values[DOWN_OFF] << 1);
    if (signal_state->prev_vol_val == 0)
    {
        switch(cur_vol_val)
        {
        case 0:
            // No button pressed
            break;
        case 1:
            // Rising edge Up button
            send_keypad_update(signal_state->update_fd, BUTTON_UP, EVENT_UPDATE);
            break;
        case 2:
            // Rising edge Down button
            send_keypad_update(signal_state->update_fd, BUTTON_DOWN, EVENT_UPDATE);
            break;
        case 3:
            // Both buttons
            break;
        default:
            // Invalid
            break;
        }
    }

    signal_state->prev_vol_val = cur_vol_val;

    const int cur_d_val = values[D_OFF];
    if (signal_state->prev_d_val == 0 && cur_d_val == 1)
    {
        send_keypad_update(signal_state->update_fd, BUTTON_D, EVENT_UPDATE);
    }

    signal_state->prev_d_val = cur_d_val;

    const uint8_t cur_val = (values[A_OFF] << 0) | (values[B_OFF] << 1);
    switch(signal_state->cur_state)
    {
    case STATE_RESET:
        switch(cur_val)
        {
        case 0:
            // No State Change
            break;
        case 1:
        {
            // A Pres
            signal_state->cur_state = STATE_A_SELECT;

            const float cur_time = get_cur_time();
            if ((signal_state->alert_val != 1) ||
                (cur_time - signal_state->alert_time) >= 2.0)
            {
                send_keypad_update(signal_state->update_fd, BUTTON_A, EVENT_SELECT);
            }
            break;
        }
        case 2:
        {
            signal_state->cur_state = STATE_B_SELECT;

            const float cur_time = get_cur_time();
            if ((signal_state -> alert_val != 2) ||
                (cur_time - signal_state->alert_time) >= 2.0)
            {
                send_keypad_update(signal_state->update_fd, BUTTON_B, EVENT_SELECT);
            }
            break;
        }
        case 3:
            // Invalid
            break;
        default:
            // Invalid
            break;
        }
        break;

    case STATE_A_SELECT:
        switch(cur_val)
        {
        case 0:
        {
            // A Release
            signal_state->cur_state = STATE_RESET;

            const float cur_time = get_cur_time();
            if ((signal_state->alert_val == 1) &&
                (cur_time - signal_state->alert_time) < 2.0)
            {
                ++signal_state->alert_counter;
                if (signal_state->alert_counter >= 3)
                {
                    send_keypad_update(signal_state->update_fd, BUTTON_A, EVENT_ALERT);

                    signal_state->alert_counter = 0;
                    signal_state->alert_val = 0;
                    signal_state->alert_time = 0.0;
                }
            }
            else
            {
                signal_state->alert_counter = 1;
                signal_state->alert_val = 1;
                signal_state->alert_time = cur_time;

                send_keypad_update(signal_state->update_fd, BUTTON_A, EVENT_RESET);
            }
            break;
        }
        case 1:
            // No State Change
            break;
        case 2:
            // Invalid
            break;
        case 3:
            // B Press
            signal_state->cur_state = STATE_A_VALUE;
            send_keypad_update(signal_state->update_fd, BUTTON_A, EVENT_VALUE);
            break;
        default:
            // Invalid
            break;
        }
        break;
    case STATE_A_VALUE:
        switch(cur_val)
        {
        case 0:
            // Invalid
            break;
        case 1:
            // B release
            signal_state->cur_state = STATE_A_INCR;
            send_keypad_update(signal_state->update_fd, BUTTON_A, EVENT_INCR);
            break;
        case 2:
            // A Release
            signal_state->cur_state = STATE_A_UPDATE;
            send_keypad_update(signal_state->update_fd, BUTTON_A, EVENT_UPDATE);
            break;
        case 3:
            break;
        default:
            // Invalid
            break;
        }
        break;
    case STATE_A_INCR:
        switch(cur_val)
        {
        case 0:
            // A Release
            signal_state->cur_state = STATE_RESET;
            send_keypad_update(signal_state->update_fd, BUTTON_A, EVENT_RESET);
            break;
        case 1:
            // No State Change
            break;
        case 2:
            // Invalid
            break;
        case 3:
            // B Press
            signal_state->cur_state = STATE_A_VALUE;
            send_keypad_update(signal_state->update_fd, BUTTON_A, EVENT_VALUE);
            break;
        default:
            // Invalid
            break;
        }
        break;
    case STATE_A_UPDATE:
        switch(cur_val)
        {
        case 0:
            // B Release
            signal_state->cur_state = STATE_RESET;
            send_keypad_update(signal_state->update_fd, BUTTON_A, EVENT_RESET);
            break;
        case 1:
            // Invalid
            break;
        case 2:
            // No State Change
            break;
        case 3:
            // A Press
            signal_state->cur_state = STATE_A_VALUE;
            send_keypad_update(signal_state->update_fd, BUTTON_A, EVENT_VALUE);
            break;
        default:
            // Invalid
            break;
        }
        break;

    case STATE_B_SELECT:
        switch(cur_val)
        {
        case 0:
        {
            // B Release
            signal_state->cur_state = STATE_RESET;

            const float cur_time = get_cur_time();
            if ((signal_state->alert_val == 2) &&
                (cur_time - signal_state->alert_time) < 2.0)
            {
                ++signal_state->alert_counter;
                if (signal_state->alert_counter >= 3)
                {
                    send_keypad_update(signal_state->update_fd, BUTTON_B, EVENT_ALERT);

                    signal_state->alert_counter = 0;
                    signal_state->alert_val = 0;
                    signal_state->alert_time = 0.0;
                }
            }
            else
            {
                signal_state->alert_counter = 1;
                signal_state->alert_val = 2;
                signal_state->alert_time = cur_time;

                send_keypad_update(signal_state->update_fd, BUTTON_B, EVENT_RESET);
            }
            break;
        }
        case 1:
            // Invalid
            break;
        case 2:
            // No state change
            break;
        case 3:
            // A Press
            signal_state->cur_state = STATE_B_VALUE;
            send_keypad_update(signal_state->update_fd, BUTTON_B, EVENT_VALUE);
            break;
        default:
            // Invalid
            break;
        }
        break;
    case STATE_B_VALUE:
        switch(cur_val)
        {
        case 0:
            // Invalid
            break;
        case 1:
            // B Release
            signal_state->cur_state = STATE_B_UPDATE;
            send_keypad_update(signal_state->update_fd, BUTTON_B, EVENT_UPDATE);
            break;
        case 2:
            // A Release
            signal_state->cur_state = STATE_B_INCR;
            send_keypad_update(signal_state->update_fd, BUTTON_B, EVENT_INCR);
            break;
        case 3:
            // No State change
            break;
        default:
            // Invalid
            break;
        }
        break;
    case STATE_B_INCR:
        switch(cur_val)
        {
        case 0:
            // B Release
            signal_state->cur_state = STATE_RESET;
            send_keypad_update(signal_state->update_fd, BUTTON_B, EVENT_RESET);
            break;
        case 1:
            // Invalid
            break;
        case 2:
            // No State change
            break;
        case 3:
            // A Press
            signal_state->cur_state = STATE_B_VALUE;
            send_keypad_update(signal_state->update_fd, BUTTON_B, EVENT_VALUE);
            break;
        default:
            // Invalid
            break;
        }
        break;
    case STATE_B_UPDATE:
        switch(cur_val)
        {
        case 0:
            // A Release
            signal_state->cur_state = STATE_RESET;
            send_keypad_update(signal_state->update_fd, BUTTON_B, EVENT_RESET);
            break;
        case 1:
            // No State change
            break;
        case 2:
            // Invalid
            break;
        case 3:
            // B Press
            signal_state->cur_state = STATE_B_VALUE;
            send_keypad_update(signal_state->update_fd, BUTTON_B, EVENT_VALUE);
            break;
        default:
            // Invalid
            break;
        }
        break;
    }
}

void handle_sigalrm(int sig)
{
    read_io = 1;
}

int main(int argc, char* argv[])
{
    if (argc < 7)
    {
        fprintf(stderr, "usage: %s <a_pin> <b_pin> <d_pin> <up_pin> <down_pin> <bias> <active_low> <debounce>\n", argv[0]);
        return 1;
    }

    const unsigned int a_pin = atoi(argv[1]);
    const unsigned int b_pin = atoi(argv[2]);
    const unsigned int d_pin = atoi(argv[3]);
    const unsigned int up_pin = atoi(argv[4]);
    const unsigned int down_pin = atoi(argv[5]);

    static const unsigned int DEBOUNCE_INTEGRATOR = atoi(argv[8]);

    signal_state.reset(new signal_state_t(DEBOUNCE_INTEGRATOR));

    if (get_lines(a_pin,
                  b_pin,
                  d_pin,
                  up_pin,
                  down_pin,
                  argv[6],
                  argv[7],
                  &signal_state->lines) < 0)
    {
        fprintf(stderr, "Failed to open lines\n");
        return 1;
    }

    signal_state->update_fd = run_keypad_updater();

    send_keypad_update(signal_state->update_fd, BUTTON_A, EVENT_RESET);
    send_keypad_update(signal_state->update_fd, BUTTON_B, EVENT_RESET);
    send_keypad_update(signal_state->update_fd, BUTTON_D, EVENT_RESET);
    send_keypad_update(signal_state->update_fd, BUTTON_UP, EVENT_RESET);
    send_keypad_update(signal_state->update_fd, BUTTON_DOWN, EVENT_RESET);

    signal(SIGALRM, handle_sigalrm);

    // Sample every 10 ms
    struct itimerval signal_interval =
    {
        { 0, 10000 },
        { 0, 10000 }
    };

    setitimer(ITIMER_REAL, &signal_interval, NULL);

    while (true)
    {
        if (read_io != 0)
        {
            read_io = 0;
            sample_tick();
        }

        // The sleep will be interrupted by the interrupt, allowing us
        // to have fairly repeatable sample timing unaffected by the
        // time it takes to perform the logic, while not having to run
        // the code in the interrupt handler itself (and being constrained
        // by the limitations of doing so).
        sleep(1);
    }

}
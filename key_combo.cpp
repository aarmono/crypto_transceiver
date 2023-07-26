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
#include <unistd.h>
#include <time.h>

#include <cstdlib>
#include <cstdint>
#include <cstdio>
#include <future>

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

static const char* EVENT_ALERT = "alert";
static const char* EVENT_RESET = "reset";
static const char* EVENT_SELECT = "select";
static const char* EVENT_VALUE = "value";
static const char* EVENT_UPDATE = "update";
static const char* EVENT_INCR = "incr";

int get_lines(unsigned int            a_pin,
              unsigned int            b_pin,
              const char*             bias,
              const char*             active_low,
              struct gpiod_line_bulk* lines)
{
    unsigned int offsets[2] = { a_pin, b_pin };

    struct gpiod_chip* chip = gpiod_chip_open_lookup("gpiochip0");
    if (chip == nullptr)
    {
        return -1;
    }

    int ret = gpiod_chip_get_lines(chip, offsets, 2, lines);
    if (ret < 0)
    {
        return ret;
    }

    const int flags = bias_flags(bias) | active_flags(active_low);
    ret = gpiod_line_request_bulk_input_flags(lines, "volume_buttons", flags);
    return ret;
}

float get_cur_time()
{
    struct timespec cur_time;
    clock_gettime(CLOCK_MONOTONIC_COARSE, &cur_time);

    return (cur_time.tv_nsec * .000000001) + cur_time.tv_sec;
}

int run_combo_update()
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

        execl("/usr/bin/combo_update.sh", "combo_update.sh", (char*)NULL);
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

void send_combo_update(int fd, const char* button, const char* event)
{
    char buf[80];
    size_t len = snprintf(buf, sizeof(buf), "%s %s\n", button, event);
    write(fd, buf, len);
}

int main(int argc, char* argv[])
{
    if (argc < 6)
    {
        fprintf(stderr, "usage: %s <a_pin> <b_pin> <bias> <active_low> <debounce>\n", argv[0]);
        return 1;
    }

    const unsigned int a_pin = atoi(argv[1]);
    const unsigned int b_pin = atoi(argv[2]);

    struct gpiod_line_bulk lines = GPIOD_LINE_BULK_INITIALIZER;
    if (get_lines(a_pin, b_pin, argv[3], argv[4], &lines) < 0)
    {
        fprintf(stderr, "Failed to open lines\n");
        return 1;
    }

    static const unsigned int DEBOUNCE_INTEGRATOR = atoi(argv[5]);
    debounce a_debounce(DEBOUNCE_INTEGRATOR);
    debounce b_debounce(DEBOUNCE_INTEGRATOR);

    int update_fd = run_combo_update();

    uint8_t alert_counter = 0;
    uint8_t alert_val = 0;
    float alert_time = 0.0;

    send_combo_update(update_fd, BUTTON_A, EVENT_RESET);
    send_combo_update(update_fd, BUTTON_B, EVENT_RESET);

    key_state_t cur_state = STATE_RESET;
    while (true)
    {
        int values[2] = {0, 0};
        if (gpiod_line_get_value_bulk(&lines, values) < 0)
        {
            fprintf(stderr, "Error reading lines\n");
        }

        values[0] = static_cast<int>(a_debounce.add_value(values[0]));
        values[1] = static_cast<int>(b_debounce.add_value(values[1]));

        const uint8_t cur_val = (values[0] << 0) | (values[1] << 1);
        switch(cur_state)
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
                cur_state = STATE_A_SELECT;

                const float cur_time = get_cur_time();
                if ((alert_val != 1) || (cur_time - alert_time) >= 2.0)
                {
                    send_combo_update(update_fd, BUTTON_A, EVENT_SELECT);
                }
                break;
            }
            case 2:
            {
                cur_state = STATE_B_SELECT;

                const float cur_time = get_cur_time();
                if ((alert_val != 2) || (cur_time - alert_time) >= 2.0)
                {
                    send_combo_update(update_fd, BUTTON_B, EVENT_SELECT);
                }
                break;
            }
            case 3:
                fprintf(stderr, "Invalid button press state\n");
                break;
            default:
                fprintf(stderr, "Invalid button press state\n");
                break;
            }
            break;

        case STATE_A_SELECT:
            switch(cur_val)
            {
            case 0:
            {
                // A Release
                cur_state = STATE_RESET;

                const float cur_time = get_cur_time();
                if ((alert_val == 1) && (cur_time - alert_time) < 2.0)
                {
                    ++alert_counter;
                    if (alert_counter >= 3)
                    {
                        send_combo_update(update_fd, BUTTON_A, EVENT_ALERT);

                        alert_counter = 0;
                        alert_val = 0;
                        alert_time = 0.0;
                    }
                }
                else
                {
                    alert_counter = 1;
                    alert_val = 1;
                    alert_time = cur_time;

                    send_combo_update(update_fd, BUTTON_A, EVENT_RESET);
                }
                break;
            }
            case 1:
                // No State Change
                break;
            case 2:
                fprintf(stderr, "Invalid button press state\n");
                break;
            case 3:
                // B Press
                cur_state = STATE_A_VALUE;
                send_combo_update(update_fd, BUTTON_A, EVENT_VALUE);
                break;
            default:
                fprintf(stderr, "Invalid button press state\n");
                break;
            }
            break;
        case STATE_A_VALUE:
            switch(cur_val)
            {
            case 0:
                fprintf(stderr, "Invalid button press state\n");
                break;
            case 1:
                // B release
                cur_state = STATE_A_INCR;
                send_combo_update(update_fd, BUTTON_A, EVENT_INCR);
                break;
            case 2:
                // A Release
                cur_state = STATE_A_UPDATE;
                send_combo_update(update_fd, BUTTON_A, EVENT_UPDATE);
                break;
            case 3:
                break;
            default:
                fprintf(stderr, "Invalid button press state\n");
                break;
            }
            break;
        case STATE_A_INCR:
            switch(cur_val)
            {
            case 0:
                // A Release
                cur_state = STATE_RESET;
                send_combo_update(update_fd, BUTTON_A, EVENT_RESET);
                break;
            case 1:
                // No State Change
                break;
            case 2:
                fprintf(stderr, "Invalid button press state\n");
                break;
            case 3:
                // B Press
                cur_state = STATE_A_VALUE;
                send_combo_update(update_fd, BUTTON_A, EVENT_VALUE);
                break;
            default:
                fprintf(stderr, "Invalid button press state\n");
                break;
            }
            break;
        case STATE_A_UPDATE:
            switch(cur_val)
            {
            case 0:
                // B Release
                cur_state = STATE_RESET;
                send_combo_update(update_fd, BUTTON_A, EVENT_RESET);
                break;
            case 1:
                fprintf(stderr, "Invalid button press state\n");
                break;
            case 2:
                // No State Change
                break;
            case 3:
                // A Press
                cur_state = STATE_A_VALUE;
                send_combo_update(update_fd, BUTTON_A, EVENT_VALUE);
                break;
            default:
                fprintf(stderr, "Invalid button press state\n");
                break;
            }
            break;

        case STATE_B_SELECT:
            switch(cur_val)
            {
            case 0:
            {
                // B Release
                cur_state = STATE_RESET;

                const float cur_time = get_cur_time();
                if ((alert_val == 2) && (cur_time - alert_time) < 2.0)
                {
                    ++alert_counter;
                    if (alert_counter >= 3)
                    {
                        send_combo_update(update_fd, BUTTON_B, EVENT_ALERT);

                        alert_counter = 0;
                        alert_val = 0;
                        alert_time = 0.0;
                    }
                }
                else
                {
                    alert_counter = 1;
                    alert_val = 2;
                    alert_time = cur_time;

                    send_combo_update(update_fd, BUTTON_B, EVENT_RESET);
                }
                break;
            }
            case 1:
                fprintf(stderr, "Invalid button press state\n");
                break;
            case 2:
                // No state change
                break;
            case 3:
                // A Press
                cur_state = STATE_B_VALUE;
                send_combo_update(update_fd, BUTTON_B, EVENT_VALUE);
                break;
            default:
                fprintf(stderr, "Invalid button press state\n");
                break;
            }
            break;
        case STATE_B_VALUE:
            switch(cur_val)
            {
            case 0:
                fprintf(stderr, "Invalid button press state\n");
                break;
            case 1:
                // B Release
                cur_state = STATE_B_UPDATE;
                send_combo_update(update_fd, BUTTON_B, EVENT_UPDATE);
                break;
            case 2:
                // A Release
                cur_state = STATE_B_INCR;
                send_combo_update(update_fd, BUTTON_B, EVENT_INCR);
                break;
            case 3:
                // No State change
                break;
            default:
                fprintf(stderr, "Invalid button press state\n");
                break;
            }
            break;
        case STATE_B_INCR:
            switch(cur_val)
            {
            case 0:
                // B Release
                cur_state = STATE_RESET;
                send_combo_update(update_fd, BUTTON_B, EVENT_RESET);
                break;
            case 1:
                fprintf(stderr, "Invalid button press state\n");
                break;
            case 2:
                // No State change
                break;
            case 3:
                // A Press
                cur_state = STATE_B_VALUE;
                send_combo_update(update_fd, BUTTON_B, EVENT_VALUE);
                break;
            default:
                fprintf(stderr, "Invalid button press state\n");
                break;
            }
            break;
        case STATE_B_UPDATE:
            switch(cur_val)
            {
            case 0:
                // A Release
                cur_state = STATE_RESET;
                send_combo_update(update_fd, BUTTON_B, EVENT_RESET);
                break;
            case 1:
                // No State change
                break;
            case 2:
                fprintf(stderr, "Invalid button press state\n");
                break;
            case 3:
                // B Press
                cur_state = STATE_B_VALUE;
                send_combo_update(update_fd, BUTTON_B, EVENT_VALUE);
                break;
            default:
                fprintf(stderr, "Invalid button press state\n");
                break;
            }
            break;
        }

        // Sample every ~10ms
        usleep(10000);
    }

}
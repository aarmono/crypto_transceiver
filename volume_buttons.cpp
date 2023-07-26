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

#include <cstdlib>
#include <cstdint>
#include <cstdio>
#include <cstring>
#include <future>

#include <gpiod.h>

#include "crypto_cfg.h"
#include "debounce.h"

int get_lines(unsigned int            up_pin,
              unsigned int            down_pin,
              const char*             bias,
              const char*             active_low,
              struct gpiod_line_bulk* lines)
{
    unsigned int offsets[2] = { up_pin, down_pin };

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

int run_volume()
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

        execl("/usr/bin/volume.sh", "volume.sh", (char*)NULL);
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

void write_volume(int fd, const char* arg)
{
    write(fd, arg, strlen(arg));
}

int main(int argc, char* argv[])
{
    if (argc < 6)
    {
        fprintf(stderr, "usage: %s <up_pin> <down_pin> <bias> <active_low> <debounce>\n", argv[0]);
        return 1;
    }

    const unsigned int up_pin = atoi(argv[1]);
    const unsigned int down_pin = atoi(argv[2]);

    struct gpiod_line_bulk lines = GPIOD_LINE_BULK_INITIALIZER;
    if (get_lines(up_pin, down_pin, argv[3], argv[4], &lines) < 0)
    {
        fprintf(stderr, "Failed to open lines\n");
        return 1;
    }

    static const unsigned int DEBOUNCE_INTEGRATOR = atoi(argv[5]);
    debounce up_debounce(DEBOUNCE_INTEGRATOR);
    debounce down_debounce(DEBOUNCE_INTEGRATOR);

    int volume_fd = run_volume();

    uint8_t prev_val = 0;
    while (true)
    {
        int values[2] = {0, 0};
        if (gpiod_line_get_value_bulk(&lines, values) < 0)
        {
            fprintf(stderr, "Error reading lines\n");
        }

        values[0] = static_cast<int>(up_debounce.add_value(values[0]));
        values[1] = static_cast<int>(down_debounce.add_value(values[1]));

        const uint8_t cur_val = (values[0] << 0) | (values[1] << 1);
        if (prev_val == 0)
        {
            switch(cur_val)
            {
            case 0:
                // No button pressed
                break;
            case 1:
                // Rising edge Up button
                write_volume(volume_fd, "up\n");
                break;
            case 2:
                // Rising edge Down button
                write_volume(volume_fd, "down\n");
                break;
            case 3:
                // Both buttons
                break;
            default:
                // Invalid
                fprintf(stderr, "Invalid button press state\n");
                break;
            }
        }

        prev_val = cur_val;
        // Sample every ~10ms
        usleep(10000);
    }

}
#include <stdio.h>
#include <string.h>
#include <stdarg.h>
#include <time.h>

#include "crypto_log.h"

crypto_log create_logger(const char* logging_file, int level)
{
    crypto_log ret;

    if (strcasecmp(logging_file, "stdout") == 0) {
        ret.file = stdout;
    }
    else if (strcasecmp(logging_file, "stderr") == 0) {
        ret.file = stderr;
    }
    else {
        ret.file = fopen(logging_file, "a");
    }

    ret.level = level;

    return ret;
}

void destroy_logger(crypto_log logger) {
    if (logger.file != stdout && logger.file != stderr) {
        fclose(logger.file);
    }
}

void log_message(crypto_log logger, int level, const char* format, ...) {
    if (level >= logger.level) {
        char buf[256] = { 0 };

        time_t cur_time = time(NULL);
        struct tm* local_time = localtime(&cur_time);
        strftime(buf, sizeof(buf) - 1, "%F %X", local_time);
        fprintf(logger.file, "%s ", buf);

        switch (level) {
            case LOG_DEBUG:
                fprintf(logger.file, "DEBUG ");
                break;
            case LOG_INFO:
                fprintf(logger.file, "INFO ");
                break;
            case LOG_NOTICE:
                fprintf(logger.file, "NOTICE ");
                break;
            case LOG_WARN:
                fprintf(logger.file, "WARN ");
                break;
            case LOG_ERROR:
                fprintf(logger.file, "ERROR ");
                break;
            default:
                fprintf(logger.file, "UNKNOWN ");
                break;
        }

        va_list args;
        va_start(args, format);
        vfprintf(logger.file, format, args);
        va_end(args);

        fprintf(logger.file, "\n");
        fflush(logger.file);
    }
}
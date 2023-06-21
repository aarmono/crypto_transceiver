#ifndef CRYPTO_LOG_H
#define CRYPTO_LOG_H

#include <stdio.h>

#define LOG_DEBUG  0
#define LOG_INFO   1
#define LOG_NOTICE 2
#define LOG_WARN   3
#define LOG_ERROR  4

#ifdef __cplusplus
extern "C" {
#endif

typedef struct {
    FILE* file;
    int   level;
} crypto_log;

crypto_log create_logger(const char* logging_file, int level);
void destroy_logger(crypto_log logger);

void log_message(crypto_log logger, int level, const char* format, ...);

#ifdef __cplusplus
}
#endif

#endif
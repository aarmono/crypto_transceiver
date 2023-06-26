#ifndef CRYPTO_COMMON_H
#define CRYPTO_COMMON_H

#include <stdio.h>

#define IV_LEN 16

#ifdef __cplusplus
extern "C"
{
#endif

struct freedv;

short rms(const short vals[], size_t len);

size_t read_input_file(short* buffer, size_t buffer_elems, FILE* file);

void configure_freedv(struct freedv* freedv);

#ifdef __cplusplus
}
#endif

#endif

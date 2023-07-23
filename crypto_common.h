#ifndef CRYPTO_COMMON_H
#define CRYPTO_COMMON_H

#include <stdio.h>
#include <string.h>

#define IV_LEN 16

#ifdef __cplusplus
extern "C"
{
#endif

struct freedv;
struct config;

short rms(const short vals[], size_t len);

size_t read_input_file(short* buffer, size_t buffer_elems, FILE* file);

void configure_freedv(struct freedv* freedv, const struct config* cfg);

#ifdef __cplusplus
}

template<class T>
void zeroize_frames(T* p, size_t n)
{
    memset(p, 0, sizeof(T) * n);
}

#endif

#endif

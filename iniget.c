#include <stdio.h>

#include "minIni.h"

char buffer[1024] = {0};

int main(int argc, char* argv[])
{
    if (argc < 4)
    {
        fprintf(stderr, "usage: %s <Section> <Key> <Filename> ...\n", argv[0]);
        return 1;
    }

    for (int i = 3; *buffer == '\0' && i < argc; ++i)
    {
        ini_gets(argv[1], argv[2], "", buffer, sizeof(buffer) - 1, argv[i]);
    }

    printf("%s", buffer);
    return 0;
}
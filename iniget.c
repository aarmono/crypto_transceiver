#include <stdio.h>

#include "minIni.h"

char buffer[1024] = {0};

int main(int argc, char* argv[])
{
    if (argc < 4)
    {
        fprintf(stderr, "usage: %s <Filename> <Section> <Key>\n", argv[0]);
        return 1;
    }

    ini_gets(argv[2], argv[3], "", buffer, sizeof(buffer) - 1, argv[1]);

    printf("%s", buffer);
    return 0;
}
#include <string.h>
#include <stdio.h>

#include "minIni.h"

char buffer[1024] = {0};

int iniget(int argc, char* argv[])
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

int iniset(int argc, char* argv[])
{
    if (argc < 5)
    {
        fprintf(stderr, "usage: %s <Section> <Key> <Value> <Filename> ...\n", argv[0]);
    }

    const char* val = *argv[3] ? argv[3] : NULL;
    for (int i = 4; i < argc; ++i)
    {
        ini_puts(argv[1], argv[2], val, argv[i]);
    }

    return 0;
}


int main(int argc, char* argv[])
{
    if (strcasestr(argv[0], "get"))
    {
        return iniget(argc, argv);
    }
    else if (strcasestr(argv[0], "set"))
    {
        return iniset(argc, argv);
    }
    else
    {
        fprintf(stderr, "Invalid command: %s\n", argv[0]);
        return 1;
    }
}

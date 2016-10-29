#include <stdio.h>
#include <string.h>

int main(int argc, char *argv[])
{
    if (argc != 3 || strlen(argv[1]) != 1 || strlen(argv[2]) != 1) {
        return 1;
    }

    printf("%d\n", argv[2][0]-argv[1][0]);
    return 0;
}

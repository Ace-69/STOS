#include "stdint.h"
#include "stdio.h"

#define OS "STOS"

void _cdecl cstart_(uint16_t bootDrive) {
    printf("Welcome to %s in C!\n", OS);
    for(;;);
}

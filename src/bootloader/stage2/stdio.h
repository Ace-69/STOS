#include "stdint.h"
#pragma once

void putc(char c);
void puts(const char* str);
void _cdecl printf(const char* format, ...);

int* printf_number(int* arg, int lenght, int radix, bool sign);

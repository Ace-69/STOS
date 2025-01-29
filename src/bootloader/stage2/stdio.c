#include "stdio.h"
#include "x86.h"

void putc(char c) {
    x86_Video_WriteCharTeletype(c, 0);
}

void puts(const char* str) {
    while (*str) {
        putc(*str++);
    }
}

#define PRINTF_STATE_NORMAL 0
#define PRINTF_STATE_LENGHT 1
#define PRINTF_STATE_LENGHT_SHORT 2
#define PRINTF_STATE_LENGHT_LONG 3
#define PRINTF_STATE_SPEC 4

#define PRINTF_LENGHT_DEFAULT 0
#define PRINTF_LENGHT_SHORT_SHORT 1
#define PRINTF_LENGHT_SHORT 2
#define PRINTF_LENGHT_LONG 3
#define PRINTF_LENGHT_LONG_LONG 4

void _cdecl printf(const char* format, ...) {
    
    int *arg = (int*)&format;
    int state = PRINTF_STATE_NORMAL;
    int lenght = PRINTF_LENGHT_DEFAULT;
    int radix = 10;
    bool sign = false;

    arg++;
    while (*format) {
        switch (state) {
            case PRINTF_STATE_NORMAL:
                switch (*format) {
                        
                    case '%': 
                        state = PRINTF_STATE_LENGHT;
                        break;
                    
                    default:
                        putc(*format);
                        break;
                }
                break;
            
            case PRINTF_STATE_LENGHT:
                switch (*format) {    
                    case 'h':
                        lenght = PRINTF_LENGHT_SHORT;
                        state = PRINTF_STATE_LENGHT_SHORT;
                        break;
                    case 'l':
                        lenght = PRINTF_LENGHT_LONG;
                        state = PRINTF_STATE_LENGHT_LONG;
                        break;
                    default:
                        goto PRINTF_STATE_SPEC_;
                }
                break;
            case PRINTF_STATE_LENGHT_SHORT:
                if(*format == 'h') {
                        lenght = PRINTF_LENGHT_SHORT_SHORT;
                        state = PRINTF_STATE_SPEC;
                } else goto PRINTF_STATE_SPEC_;
                break;
            case PRINTF_STATE_LENGHT_LONG:
                if(*format == 'l') {
                        lenght = PRINTF_LENGHT_LONG_LONG;
                        state = PRINTF_STATE_SPEC;
                } else goto PRINTF_STATE_SPEC_;
                break;
            case PRINTF_STATE_SPEC:
            PRINTF_STATE_SPEC_: 
                switch (*format) {
                    case 'c':
                        putc((char)*arg);
                        arg++;
                        break;
                    case 's':
                        puts(*(char**)arg);
                        arg++;
                        break;
                    case '%':
                        putc('%');
                        break;
                    case 'd':
                    case 'i':
                        radix = 10;
                        sign = true;
                        arg = printf_number(arg, lenght, radix, sign);
                        break;

                    case 'u': 
                        radix = 10;
                        sign = false;
                        arg = printf_number(arg, lenght, radix, sign);
                        break;
                    
                    case 'x':
                    case 'X':
                    case 'p':
                        radix = 16;
                        sign = false;
                        arg = printf_number(arg, lenght, radix, sign);
                        break;
                    case 'o':
                        radix = 8;
                        sign = false;
                        arg = printf_number(arg, lenght, radix, sign);
                        break;

                    // ignore other specifiers
                    default:
                        break;
                }
                // reset state
                state = PRINTF_STATE_NORMAL;
                lenght = PRINTF_LENGHT_DEFAULT;
                radix = 10;
                sign = false;
                break;

        }
        
        format++;
    }
    
}

const char g_HexChars[] = "0123456789ABCDEF";

int* printf_number(int* arg, int lenght, int radix, bool sign) {
    char buffer[32];
    unsigned long long number;
    int numSign = 1;
    int pos = 0;

    // process number length
    switch (lenght) {
        case PRINTF_LENGHT_SHORT_SHORT:
        case PRINTF_LENGHT_SHORT:
        case PRINTF_LENGHT_DEFAULT:
            if (sign) {
                int n = *arg;
                if (n < 0) {
                    numSign = -1;
                    n = -n;
                }
                number = (unsigned long long)n;
            } else {
                number = *(unsigned int*)arg;
            }
            arg++;
            break;
        case PRINTF_LENGHT_LONG:
            if (sign) {
                long n = *(long int*)arg;
                if (n < 0) {
                    numSign = -1;
                    n = -n;
                }
                number = (unsigned long long)n;
            } else {
                number = *(unsigned long int*)arg;
            }
            arg += 2;
            break;
        case PRINTF_LENGHT_LONG_LONG:
            if (sign) {
                long long n = *(long long int*)arg;
                if (n < 0) {
                    numSign = -1;
                    n = -n;
                }
                number = (unsigned long long)n;
            } else {
                number = *(unsigned long long*)arg;
            }
            arg += 4;
            break;
    }

    // convert number to string (ASCII)
    do {
        uint32_t rem;
        x86_div64_32(number, radix, &number, &rem);
        buffer[pos++] = g_HexChars[rem];
    } while (number > 0);

    // add sign
    if (sign && numSign < 0) {
        buffer[pos++] = '-';
    }
    
    // reverse string
    while (--pos >= 0) {
        putc(buffer[pos]);
    }
    return arg;
}

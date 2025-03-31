#include "util.h"
#include <sys/time.h>
#include <stdlib.h>
#include <stddef.h>
#include <string.h>

long long get_current_time_millis() {
    struct timeval tv;
    gettimeofday(&tv, NULL);
    return (long long) tv.tv_sec * 1000 + tv.tv_usec / 1000;
}

// strncpy but the last character in dest is always NULL
void terminated_strncpy(char* restrict dest, const char* restrict src, size_t n) {
    if (n < 1) return;
    strncpy(dest, src, n);
    dest[n - 1] = '\0';
}

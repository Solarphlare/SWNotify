#pragma once
#include <stddef.h>

long long get_current_time_millis();
void terminated_strncpy(char* restrict dest, const char* restrict src, size_t n);

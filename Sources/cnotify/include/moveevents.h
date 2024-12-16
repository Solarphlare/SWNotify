#pragma once
#include <stdint.h>
#include "types.h"

#define MAX_TRACKED_EVENTS 512

extern struct move_event tracked_events[sizeof(struct move_event) * MAX_TRACKED_EVENTS];
extern int tracked_count;

void track_event(uint32_t wd, uint32_t cookie, const char* name);
int find_and_remove_event(uint32_t cookie, char* matched_name);

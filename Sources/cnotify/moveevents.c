#include "include/moveevents.h"
#include "util.h"
#include <stdint.h>
#include <string.h>
#include <time.h>

struct move_event tracked_events[sizeof(struct move_event) * MAX_TRACKED_EVENTS] = {};
int tracked_count = 0;

void track_event(uint32_t wd, uint32_t cookie, const char* name) {
    if (tracked_count >= MAX_TRACKED_EVENTS) {
        return;
    }

    struct move_event* event = &tracked_events[tracked_count];
    event->cookie = cookie;
    event->wd = wd;
    strncpy(event->name, name, sizeof(event->name));
    event->timestamp = get_current_time_millis();
    tracked_count++;
}

int find_and_remove_event(uint32_t cookie, char* matched_name) {
    for (int i = 0; i < tracked_count; i++) {
        if (tracked_events[i].cookie == cookie) {
            if (matched_name != NULL) {
                strncpy(matched_name, tracked_events[i].name, 1024);
            }

            // Remove the event by shifting all events after it back by one
            for (int j = i; j < tracked_count - 1; j++) {
                tracked_events[j] = tracked_events[j + 1];
            }

            tracked_count--;
            return 1;
        }
    }

    return 0;
}

#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include "moveevents.h"
#include "types.h"
#include "util.h"
#include "uthash.h"

int tracked_count = 0;
struct move_event* move_events = NULL;

void track_event(uint32_t wd, uint32_t cookie, const char* name) {
    struct move_event* new_event = (struct move_event*) malloc(sizeof(struct move_event));
    if (new_event == NULL) {
        return;
    }

    new_event->wd = wd;
    new_event->cookie = cookie;
    new_event->timestamp = get_current_time_millis();
    terminated_strncpy(new_event->name, name, 1024);

    HASH_ADD_INT(move_events, cookie, new_event);
    tracked_count++;
}

int find_and_remove_event(uint32_t cookie, char* matched_name) {
    struct move_event* found_event;
    HASH_FIND_INT(move_events, &cookie, found_event);

    if (found_event) {
        if (matched_name != NULL) {
            terminated_strncpy(matched_name, found_event->name, 1024);
        }

        remove_event(found_event);
        return 1;
    }

    return 0;
}

void remove_event(struct move_event* event) {
    if (event) {
        HASH_DEL(move_events, event);
        free(event);
        tracked_count--;
    }
}

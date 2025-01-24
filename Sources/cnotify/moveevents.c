#include "moveevents.h"
#include "types.h"
#include "util.h"
#include <stdlib.h>
#include <stdint.h>
#include <string.h>

struct node tracked_events[MAX_TRACKED_EVENTS] = {};
int tracked_count = 0;

void track_event(uint32_t wd, uint32_t cookie, const char* name) {
    const int index = cookie % MAX_TRACKED_EVENTS;

    if (tracked_events[index].data == NULL) { // slot is empty
        tracked_events[index].data = (struct move_event*) malloc(sizeof(struct move_event));
        tracked_events[index].next = NULL;
        struct move_event* event = tracked_events[index].data;

        event->wd = wd;
        event->cookie = cookie;
        event->timestamp = get_current_time_millis();
        strncpy(event->name, name, sizeof(event->name));
        event->name[sizeof(event->name) - 1] = '\0';
    }
    else { // slot is not empty. traverse the linked list until we find one
        struct node* node = &tracked_events[index];
        while (node->next != NULL) {
            node = node->next;
        }

        node->next = malloc(sizeof(struct node));
        node->next->data = malloc(sizeof(struct move_event));
        node->next->next = NULL;
        struct move_event* event = node->next->data;

        event->wd = wd;
        event->cookie = cookie;
        event->timestamp = get_current_time_millis();
        strncpy(event->name, name, sizeof(event->name) - 1);
        event->name[sizeof(event->name) - 1] = '\0';
    }

    tracked_count++;
}

int find_and_remove_event(uint32_t cookie, char* matched_name) {
    const int index = cookie % MAX_TRACKED_EVENTS;
    struct node* node = &tracked_events[index];
    struct node* previous_node = NULL;

    if (node->data == NULL) {
        return 0;
    }

    while (node->data->cookie != cookie) {
        if (node->next == NULL) {
            return 0;
        }

        previous_node = node;
        node = node->next;
    }

    if (matched_name != NULL) {
        strncpy(matched_name, node->data->name, 1024);
        matched_name[1023] = '\0';
    }

    free(node->data);
    node->data = NULL;

    if (previous_node != NULL) {
        if (node->next == NULL) {
            previous_node->next = NULL;
        }
        else {
            previous_node->next = node->next;
        }

        free(node);
    }
    else {
        // if this is the only node in the list
        if (node->next == NULL) {
            free(node->data);
            node->data = NULL;
        }
        else { // copy the next node's contents into the head
            struct node* temp = node->next;

            node->data = temp->data;
            node->next = temp->next;

            free(temp);
        }
    }

    tracked_count--;
    return 1;
}

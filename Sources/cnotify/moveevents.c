#include "moveevents.h"
#include "types.h"
#include "util.h"
#include <stdlib.h>
#include <stdint.h>
#include <string.h>

int tracked_count = 0;

struct node* head = NULL;
struct node* tail = NULL;

void track_event(uint32_t wd, uint32_t cookie, const char* name) {
    struct node* new_node = (struct node*) malloc(sizeof(struct node));
    if (new_node == NULL) {
        return;
    }

    struct move_event* new_event = (struct move_event*) malloc(sizeof(struct move_event));
    if (new_event == NULL) {
        free(new_node);
        return;
    }

    new_node->data = new_event;
    new_event->wd = wd;
    new_event->cookie = cookie;
    new_event->timestamp = get_current_time_millis();
    strncpy(new_event->name, name, sizeof(new_event->name) - 1);
    new_event->name[sizeof(new_event->name) - 1] = '\0';

    if (head == NULL) {
        head = new_node;
        tail = new_node;
        new_node->next = NULL;
        new_node->prev = NULL;
    }
    else {
        tail->next = new_node;
        new_node->prev = tail;
        new_node->next = NULL;
        tail = new_node;
    }

    tracked_count++;
}

int find_and_remove_event(uint32_t cookie, char* matched_name) {
    for (struct node* node = head; node != NULL; node = node->next) {
        if (node->data->cookie == cookie) {
            if (matched_name != NULL) {
                strncpy(matched_name, node->data->name, sizeof(node->data->name));
                matched_name[sizeof(node->data->name) - 1] = '\0';
            }

            remove_event(node);
            return 1;
        }
    }

    return 0;
}

void remove_event(struct node* node) {
    if (node == NULL) return;

    if (node->prev == NULL) { // head
        head = node->next;

        if (head != NULL) {
            head->prev = NULL;
        }
        else {
            head = NULL;
            tail = NULL;
        }
    }
    else if (node->next == NULL) { // tail
        node->prev->next = NULL;
    }
    else { // middle
        node->prev->next = node->next;
        node->next->prev = node->prev;
    }

    free(node->data);
    free(node);
    tracked_count--;
}

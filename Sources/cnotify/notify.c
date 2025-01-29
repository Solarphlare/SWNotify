#include <stdlib.h>
#include <sys/inotify.h>
#include <unistd.h>
#include <pthread.h>
#include <errno.h>
#include <sys/poll.h>
#include "util.h"
#include "notify.h"
#include "types.h"
#include "moveevents.h"

struct callback_collection callbacks = {
    NULL,
    NULL,
    NULL,
    NULL,
    NULL,
    NULL
};

static int inotify_fd = -1;
static int initialized = 0;
static pthread_t thread_id = -1;

int notifier_init() {
    if (initialized) return 0;
    initialized = 1;

    inotify_fd = inotify_init();

    if (inotify_fd < 0) {
        return -1;
    }

    return 0;
}

int add_watch(const char* filepath, int flags) {
    int watch = inotify_add_watch(inotify_fd, filepath, flags);

    if (watch < 0) {
        switch (errno) {
            case ENOENT: // Directory doesn't exist
                return -1;
            case EACCES: // Permission denied
                return -2;
            default: // No idea what happened, but it isn't good.
                return -3;
        }
    }

    return watch;
}

int remove_watch(int watch) {
    return inotify_rm_watch(inotify_fd, watch);
}

int set_callback(void (*callback)(const char*, int), int flag) {
    switch (flag) {
        case IN_CREATE:
            callbacks.create = callback;
            break;
        case IN_DELETE:
            callbacks.remove = callback;
            break;
        case IN_MODIFY:
            callbacks.modify = callback;
            break;
        case IN_MOVED_FROM:
            callbacks.move_from = callback;
            break;
        case IN_MOVED_TO:
            callbacks.move_to = callback;
            break;
        default:
            return -1;
    }

    return 0;
}

// Separate function for rename callback because it has a different signature
int set_rename_callback(void (*callback)(const char*, const char*, int)) {
    callbacks.rename = callback;
    return 0;
}

static void* handle_events(void* _vargp) {
    pthread_setcanceltype(PTHREAD_CANCEL_ASYNCHRONOUS, NULL);

    char buf[4096];
    ssize_t length;
    struct pollfd fds[1];

    fds[0].fd = inotify_fd;
    fds[0].events = POLLIN;

    while (1) {
        int ret = poll(fds, 1, 250); // 1 descriptor, 250ms timeout

        // Something went wrong with poll
        if (ret < 0) {
            break;
        }

        // Check for, dispatch, and remove any IN_MOVE_FROM events that need to be dispatched to Swift
        // An event will be dispatched if it has been in tracked_events for more than 500ms
        if (tracked_count > 0) {
            long long now = get_current_time_millis();

            for (struct node* node = head; node != NULL;) {
                if ((now - node->data->timestamp) > 500) {
                    if (callbacks.move_from) {
                        callbacks.move_from(node->data->name, node->data->wd);
                    }

                    struct node* temp = node;
                    node = node->next;
                    remove_event(temp);
                }
                else {
                    node = node->next;
                }
            }
        }

        // No events to read, poll again
        if (ret == 0) {
            continue;
        }

        length = read(inotify_fd, buf, sizeof(buf));

        if (length < 0) {
            break;
        }

        for (char* ptr = buf; ptr < buf + length;) {
            struct inotify_event* event = (struct inotify_event*) ptr;

            if (event->mask & IN_CREATE && callbacks.create) {
                callbacks.create(event->name, event->wd);
            }
            else if (event->mask & IN_DELETE && callbacks.remove) {
                callbacks.remove(event->name, event->wd);
            }
            else if (event->mask & IN_MODIFY && callbacks.modify) {
                callbacks.modify(event->name, event->wd);
            }
            else if (event->mask & IN_MOVED_FROM) {
                // Track the event so we can dispatch it later
                track_event(event->wd, event->cookie, event->name);
            }
            else if (event->mask & IN_MOVED_TO) {
                char matched_name[1024];
                if (find_and_remove_event(event->cookie, matched_name)) { // Check if this is a rename event - if it is, dispatch it
                    if (callbacks.rename) {
                        callbacks.rename(matched_name, event->name, event->wd);
                    }
                }
                else if (callbacks.move_to) { // Otherwise, it's an IN_MOVE_TO event - dispatch it
                    callbacks.move_to(event->name, event->wd);
                }
            }

            ptr += sizeof(struct inotify_event) + event->len;
        }
    }

    return NULL;
}

void start_notifier() {
    pthread_attr_t attr;
    pthread_attr_init(&attr);
    pthread_attr_setdetachstate(&attr, PTHREAD_CREATE_DETACHED);

    pthread_create(&thread_id, &attr, handle_events, NULL);
}

void stop_notifier() {
    close(inotify_fd);
    pthread_cancel(thread_id);
    inotify_fd = -1;
    initialized = 0;
}

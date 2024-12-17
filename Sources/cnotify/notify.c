#include <stdlib.h>
#include <sys/inotify.h>
#include <unistd.h>
#include <pthread.h>
#include <errno.h>
#include <sys/poll.h>
#include "include/util.h"
#include "include/notify.h"
#include "include/types.h"
#include "include/moveevents.h"

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
            case ENOENT:
                return -1;
            case EACCES:
                return -2;
            default:
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
        int ret = poll(fds, 1, 250);

        if (ret < 0) {
            break;
        }
        else if (ret == 0) {
            long long now = get_current_time_millis();
            for (int i = 0; i < tracked_count; i++) {
                if (now - tracked_events[i].timestamp > 500 && callbacks.move_from) {
                    callbacks.move_from(tracked_events[i].name, tracked_events[i].wd);
                    find_and_remove_event(tracked_events[i].cookie, NULL);
                }
            }

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
                track_event(event->wd, event->cookie, event->name);
            }
            else if (event->mask & IN_MOVED_TO) {
                char matched_name[1024];
                if (find_and_remove_event(event->cookie, matched_name)) {
                    if (callbacks.rename) {
                        callbacks.rename(matched_name, event->name, event->wd);
                    }
                }
                else if (callbacks.move_to) {
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

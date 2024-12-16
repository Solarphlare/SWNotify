#include <stdlib.h>
#include <sys/inotify.h>
#include <unistd.h>
#include <pthread.h>
#include <errno.h>
#include "include/types.h"
#include "include/notify.h"

static struct callback_function_collection callbacks = {
    .create = NULL,
    .remove = NULL,
    .modify = NULL,
    .moved_from = NULL,
    .moved_to = NULL
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
        default:
            return -1;
    }

    return 0;
}

int set_move_callback(void (*callback)(const char*, int, int), int flag) {
    switch (flag) {
        case IN_MOVED_FROM:
            callbacks.moved_from = callback;
            break;
        case IN_MOVED_TO:
            callbacks.moved_to = callback;
            break;
        default:
            return -1;
    }

    return 0;
}

static void* handle_events(void* _vargp) {
    pthread_setcanceltype(PTHREAD_CANCEL_ASYNCHRONOUS, NULL);

    char buf[4096];
    ssize_t length;

    while (1) {
        length = read(inotify_fd, buf, sizeof(buf));

        if (length < 0) {
            break;
        }

        for (char* ptr = buf; ptr < buf + length;) {
            struct inotify_event* event = (struct inotify_event*) ptr;

            if (event->mask & IN_CREATE && callbacks.create) {
                callbacks.create(event->name, event->wd);
            } else if (event->mask & IN_DELETE && callbacks.remove) {
                callbacks.remove(event->name, event->wd);
            } else if (event->mask & IN_MODIFY && callbacks.modify) {
                callbacks.modify(event->name, event->wd);
            } else if (event->mask & IN_MOVED_FROM && callbacks.moved_from) {
                callbacks.moved_from(event->name, event->cookie, event->wd);
            } else if (event->mask & IN_MOVED_TO && callbacks.moved_to) {
                callbacks.moved_to(event->name, event->cookie, event->wd);
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

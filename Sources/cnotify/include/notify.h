#include <sys/inotify.h>

int notifier_init();
int add_watch(const char* filepath, int flags);
int remove_watch(int watch);
int set_callback(void (*callback)(const char*), int flag);
void set_move_callback(void (*callback)(const char*, const char*));
void start_notifier();
void stop_notifier();

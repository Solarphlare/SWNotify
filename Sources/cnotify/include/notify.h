#pragma once

int notifier_init();
int add_watch(const char* filepath, int flags);
int remove_watch(int watch);
int set_callback(void (*callback)(const char*, int), int flag);
int set_rename_callback(void (*callback)(const char*, const char*, int));
void start_notifier();
void stop_notifier();

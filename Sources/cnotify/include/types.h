#pragma once
#include <stdint.h>

struct callback_collection {
    // const char* name, int wd
    void (*create)(const char*, int);
    void (*remove)(const char*, int);
    void (*modify)(const char*, int);
    void (*move_from)(const char*, int);
    void (*move_to)(const char*, int);
    // const char* old_name, const char* new_name, int wd
    void (*rename)(const char*, const char*, int);
};

struct move_event {
    uint32_t cookie;
    char name[1024];
    long long timestamp;
    uint32_t wd;
};


struct node {
    struct move_event* data;
    struct node* next;
};

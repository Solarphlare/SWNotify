#pragma once

struct callback_function_collection {
    void (*create)(const char*, int);
    void (*remove)(const char*, int);
    void (*modify)(const char*, int);
    void (*moved_from)(const char*, int, int);
    void (*moved_to)(const char*, int, int);
};

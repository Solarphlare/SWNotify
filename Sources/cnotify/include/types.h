#pragma once

struct callback_function_collection {
    void (*create)(const char*);
    void (*remove)(const char*);
    void (*modify)(const char*);
    void (*rename)(const char*, const char*);
};

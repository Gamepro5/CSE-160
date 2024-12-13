#ifndef CHAT_H
#define CHAT_H

typedef struct username_store_t
{
    uint8_t username[11];
    bool isClientSide;
}
username_store_t;

#endif
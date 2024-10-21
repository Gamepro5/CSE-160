#ifndef ROUTE_H
#define ROUTE_H

#define MAX_ROUTING 20
#define TABLE_CACHE_SIZE 20
#define PACKET_CACHE_SIZE 50

// #define INFINITY 65535

#include "packet.h"

typedef struct Route
{
	nx_uint16_t dest;
    nx_uint16_t to;
    nx_uint8_t cost;
    nx_uint16_t toAlt;
    nx_uint8_t costAlt;
}
Route;

typedef struct LSA
{
    nx_uint8_t cost;
}
LSA;

typedef struct TableCache
{
    nx_uint16_t floodsrc;
    nx_uint16_t received;
    Neighbor table[MAX_NEIGHBOR];
}
TableCache;

#endif /* NEIGHBOR_H */
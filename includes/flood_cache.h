#ifndef FLOOD_CACHE_H
#define FLOOD_CACHE_H

#define FLOOD_CACHE_SIZE 50

#include "packet.h"

typedef nx_struct flood_cache
{
	nx_uint16_t floodsrc;
	nx_uint16_t seq;
	nx_uint8_t received;
	nx_uint16_t dest;
	nx_uint8_t payload[FLOODING_MAX_PAYLOAD_SIZE];
}
flood_cache;

typedef struct pack_cache
{
	nx_uint16_t src;
	nx_uint16_t seq;
	nx_uint8_t received;
	nx_uint16_t dest;
	bool sentAlt;
	nx_uint8_t payload[ROUTING_MAX_PAYLOAD_SIZE];
}
pack_cache;

#endif

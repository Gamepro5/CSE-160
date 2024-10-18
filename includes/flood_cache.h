#ifndef FLOOD_CACHE_H
#define FLOOD_CACHE_H

#define FLOOD_CACHE_SIZE 20

typedef nx_struct flood_cache
{
	nx_uint16_t floodsrc;
	nx_uint16_t seq;
	nx_uint8_t receivedReply;
}
flood_cache;

#endif

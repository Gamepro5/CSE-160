#ifndef FLOOD_CACHE_H
#define FLOOD_CACHE_H

typedef nx_struct flood_cache{
	nx_uint16_t dest;
	nx_uint16_t src;
	nx_uint8_t payload[20];
}flood_cache;

#endif

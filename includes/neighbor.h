//Author: UCM ANDES Lab
//Date: 2/15/2012
#ifndef NEIGHBOR_H
#define NEIGHBOR_H

#include "packet.h"

#define MAX_NEIGHBOR 20

typedef struct Neighbor
{
	nx_uint16_t address;
    float quality;
    bool active;
    nx_uint8_t received;
    nx_uint16_t lastSeq;
}
Neighbor;

#endif /* NEIGHBOR_H */

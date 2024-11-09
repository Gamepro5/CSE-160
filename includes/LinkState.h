//Author: UCM ANDES Lab
//Date: 2/15/2012
#ifndef LINKSTATE_H
#define LINKSTATE_H

#include "packet.h"
#include "neighbor.h"

#define min(a, b) ((a) < (b) ? (a) : (b))

typedef struct LinkState
{
    bool receivedFirst;
    nx_uint16_t firstReceived;
    nx_uint16_t lastReceived;
    nx_uint16_t offset;
    // Neighbor neighbors[MAX_NEIGHBOR];
    uint8_t neighbors[MAX_NEIGHBOR];
}
LinkState;

#endif /* NEIGHBOR_H */

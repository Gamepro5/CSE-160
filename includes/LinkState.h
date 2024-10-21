//Author: UCM ANDES Lab
//Date: 2/15/2012
#ifndef LINKSTATE_H
#define LINKSTATE_H

#include "packet.h"
#include "neighbor.h"

typedef struct LinkState
{
	bool considered;
    nx_uint16_t table[MAX_NEIGHBOR];
}
LinkState;

#endif /* NEIGHBOR_H */

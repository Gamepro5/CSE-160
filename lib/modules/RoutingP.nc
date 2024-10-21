module RoutingP
{
    provides interface Routing;
    uses interface NeighborDiscovery;
    uses interface Flooding;

    uses interface Timer<TMilli> as waitTimer;
    uses interface SimpleSend as Sender;
}

implementation
{
    void dijkstra();
    bool isNeighbor(uint16_t NODE_ID);
    
    Neighbor neighborTable[MAX_NEIGHBOR];
    uint8_t neighborCount;
    LinkState linkStates[MAX_ROUTING];
    Route table[MAX_ROUTING];
    TableCache cache[TABLE_CACHE_SIZE];
    uint8_t tablePointer = 0;
    uint8_t cachePointer = 0;
    bool initialized = FALSE;

    pack sendPackage;
    int i;

    command void Routing.init()
    {
        call waitTimer.startOneShot(15000);
    }

    event void waitTimer.fired()
    {
        // if(initialized == FALSE)
        // {
        //     for(i = 0; i < MAX_NEIGHBOR; i++)
        //     {
        //         if(neighborTable[i].address != 0)
        //         {
        //             Route update;
        //             update.dest = neighborTable[i].address;
        //             update.to = neighborTable[i].address;
        //             update.cost = 1;
        //             update.toAlt = 0;
        //             update.costAlt = INFINITY;
        //             table[tablePointer++] = update;
        //         }
        //         if(tablePointer >= MAX_ROUTING) tablePointer = 0;
        //     }
        //     initialized = TRUE;
        // }
        // call Routing.floodLinkState();
        // call waitTimer.startOneShot(15000);
    }

    event void NeighborDiscovery.updateNeighbors(void* data, uint8_t len, uint8_t count)
    {
        memcpy(&neighborTable, data, len);
        neighborCount = count;
        // call Routing.floodLinkState();
    }

    command void Routing.floodLinkState()
    {
        // // Reused space for sending parsed payload across multiple packets

        // payload.hops = 1;
        
        // // Parse and send the data
        // for(i = 0; i < sizeof(Neighbor)*MAX_NEIGHBOR - FLOODING_MAX_PAYLOAD_SIZE; i = i + FLOODING_MAX_PAYLOAD_SIZE)
        // {
        //     memcpy(&payload, &table + i, FLOODING_MAX_PAYLOAD_SIZE);
        //     call Flooding.startFlood(AM_BROADCAST_ADDR, &payload, PROTOCOL_LINK_STATE);
        // }
        // memcpy(&payload, &table + i, sizeof(Neighbor)*MAX_NEIGHBOR - i);
        // call Flooding.startFlood(AM_BROADCAST_ADDR, &payload, PROTOCOL_LINK_STATE);
        dbg(ROUTING_CHANNEL, "STARTING LINKSTATE FLOOD\n");
        
        i = 0;
        while(i < neighborCount)
        {
            int j;
            uint8_t payload[FLOODING_MAX_PAYLOAD_SIZE];
            uint16_t* writeToPayload = &payload;
            
            dbg(ROUTING_CHANNEL, "BEGIN WHILE LOOP\n");

            for(j = 0; j < FLOODING_MAX_PAYLOAD_SIZE/2; j++)
            {
                dbg(ROUTING_CHANNEL, "BEGIN FOR LOOP J=%i\n", j);
                
                if(i == neighborCount)
                {
                    *(writeToPayload + j) = 0;
                }
                // Check for active here using ACTIVE property later
                else if(neighborTable[i].active == TRUE)
                {
                    // memcpy(writeToPayload + j, &(neighborTable[i].address), sizeof(uint16_t));
                    *(writeToPayload + j) = neighborTable[i].address;
                    dbg(ROUTING_CHANNEL, "Neighbor %i at index %i copied to position %i in payload\n", neighborTable[i].address, i, j);
                    i++;
                }
                else
                {
                    // memcpy(writeToPayload + j, &zero, sizeof(uint16_t));
                    *(writeToPayload + j) = 0;
                    i++;
                }
            }
            if(i == neighborCount) payload[FLOODING_MAX_PAYLOAD_SIZE - 1] = 1;
            else payload[FLOODING_MAX_PAYLOAD_SIZE - 1] = 0;

            memcpy(linkStates[TOS_NODE_ID - 1].neighbors, &payload, FLOODING_MAX_PAYLOAD_SIZE - 1);

            dbg(ROUTING_CHANNEL, "INIT FLOOD\n");
            call Flooding.startFlood(AM_BROADCAST_ADDR, &payload, PROTOCOL_LINK_STATE);
        }
        dbg(ROUTING_CHANNEL, "FINISHED LINKSTATE FLOOD\n");
    }
    
    command void Routing.receivedLinkStatePacket(pack* myMsg)
    {
        pack myMsgCopy = *myMsg;
        floodingheader* header = (floodingheader*)&(myMsgCopy.payload);
        uint16_t* payload = header->payload;

        dbg(ROUTING_CHANNEL, "RECEIVED %sLINK STATE FROM %i: ", (header->payload[FLOODING_MAX_PAYLOAD_SIZE - 1] == 1) ? "LAST " : "", header->floodsrc);
        
        if(call Flooding.flood(myMsg) == SUCCESS)
        {   
            dbg(ROUTING_CHANNEL, "%i: ", header->floodsrc);
            for(i = 0; i < FLOODING_MAX_PAYLOAD_SIZE/2; i++)
            {
                dbg_clear(ROUTING_CHANNEL, "%u, ", *(payload + i));
                linkStates[header->floodsrc - 1].neighbors[i] = *(payload + i);
            }
            dbg_clear(ROUTING_CHANNEL, "\n");
        }
    }

    command void Routing.forward(pack* myMsg)
    {
        if(myMsg->dest == TOS_NODE_ID)
        {
            dbg(ROUTING_CHANNEL, "Payload received from %i: \"%s\"\n", myMsg->src, myMsg->payload);
            return;
        }
        if(myMsg->src == TOS_NODE_ID) dbg(ROUTING_CHANNEL, "Sending \"%s\" to %i. Forwarding to %i..\n", myMsg->payload, myMsg->dest, table[myMsg->dest-1].to);
        else dbg(ROUTING_CHANNEL, "Src: %i, Dest: %i, Forwarding to %i..\n", myMsg->src, myMsg->dest, table[myMsg->dest-1].to);
        call Sender.send(*myMsg, table[myMsg->dest-1].to);
    }

    command void Routing.printLinkState()
    {
        dbg(ROUTING_CHANNEL, "DEST   TO   COST   ALT   ALTCOST\n");
        for(i = 0; i < MAX_ROUTING; i++)
        {
            if(table[i].dest != 0)
            dbg_clear(ROUTING_CHANNEL, "                              %02i   %02i    %03i    %02i    %03i\n", table[i].dest, table[i].to, table[i].cost, table[i].toAlt, table[i].costAlt);
            // int j;
            // dbg(ROUTING_CHANNEL, "%i: ", i+1);
            // for(j = 0; j < MAX_NEIGHBOR; j++)
            // {
            //     if(linkStates[i].neighbors[j] != 0)
            //         dbg_clear(ROUTING_CHANNEL, "%i ", linkStates[i].neighbors[j]);
            // }
            // dbg_clear(ROUTING_CHANNEL, "\n");
        }
    }

    command void Routing.calculateSP()
    {
        dijkstra();
    }

    void dijkstra()
    {
        Route update;

        for(i = 0; i < MAX_ROUTING; i++)
        {
            if(i+1 == TOS_NODE_ID)
            {
                update.dest = TOS_NODE_ID;
                update.to = 0;
                update.cost = 0;
                update.toAlt = 0;
                update.costAlt = 0;
                update.considered = TRUE;
            }
            else if(isNeighbor(i+1) == TRUE)
            {
                update.dest = i+1;
                update.to = i+1;
                update.cost = 1;
                update.toAlt = 0;
                update.costAlt = INFINITY;
                update.considered = FALSE;
            }
            else
            {
                update.dest = i+1;
                update.to = 0;
                update.cost = INFINITY;
                update.toAlt = 0;
                update.costAlt = INFINITY;
                update.considered = FALSE;
            }
            table[i] = update;
        }
        
        while(1 == 1)
        {
            uint8_t minCost = INFINITY;
            
            bool allNodesConsidered = TRUE;
            for(i = 0; i < MAX_ROUTING; i++)
            {
                if(table[i].considered == FALSE)
                {
                    allNodesConsidered = FALSE;
                    break;
                }
            }
            if(allNodesConsidered == TRUE) break;
            
            for(i = 0; i < MAX_ROUTING; i++)
            {
                if(table[i].considered == TRUE){ }
                else if(minCost == (uint8_t)INFINITY) minCost = i;
                else if(table[i].cost < table[minCost].cost) minCost = i;
            }

            for(i = 0; i < MAX_NEIGHBOR; i++)
            {
                uint16_t current = linkStates[minCost].neighbors[i];
                if(current != 0 && table[current-1].considered == FALSE)
                {
                    dbg(ROUTING_CHANNEL, "Calculating new cost for %i from %i... \n", current, minCost+1);
                    if(table[minCost].cost + 1 < table[current-1].cost)
                    {
                        table[current-1].costAlt = table[current-1].cost;
                        table[current-1].toAlt = table[current-1].to;

                        table[current-1].cost = table[minCost].cost + 1;
                        table[current-1].to = table[minCost].to;
                    }
                    else if(table[minCost].cost + 1 < table[current-1].costAlt)
                    {
                        table[current-1].costAlt = table[minCost].cost + 1;
                        table[current-1].toAlt = table[minCost].to;
                    }
                }
            }
            table[minCost].considered = TRUE;
        }
    }

    bool isNeighbor(uint16_t NODE_ID)
    {
        int j;
        for(j = 0; j < neighborCount; j++)
        {
            if(neighborTable[j].address == NODE_ID) return TRUE;
        }
        return FALSE;
    }
}
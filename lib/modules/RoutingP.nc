module RoutingP
{
    provides interface Routing;
    uses interface NeighborDiscovery;
    uses interface Flooding;

    uses interface Timer<TMilli> as waitTimer;
}

implementation
{
    void dijkstra();

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
        bool finished = FALSE;
        bool found = FALSE;

        dbg(ROUTING_CHANNEL, "RECEIVED %sLINK STATE FROM %i: ", (header->payload[FLOODING_MAX_PAYLOAD_SIZE - 1] == 1) ? "LAST " : "", header->floodsrc);
        
        if(call Flooding.flood(myMsg) == SUCCESS)
        {   
            dbg(ROUTING_CHANNEL, "%i: ", header->floodsrc);
            for(i = 0; i < FLOODING_MAX_PAYLOAD_SIZE/2; i++)
            {
                dbg_clear(ROUTING_CHANNEL, "%u, ", *(payload + i));
            }
            dbg_clear(ROUTING_CHANNEL, "\n");

            // Store into table
            // linkStates[header->floodsrc - 1].table = header->payload;
            linkStates[header->floodsrc - 1].considered = FALSE;
            memcpy(linkStates[header->floodsrc - 1].table, header->payload, FLOODING_MAX_PAYLOAD_SIZE - 1);
        }
    }

    // command void Routing.receivedLinkStatePacket(pack* myMsg)
    // {
    //     floodingheader* header = (floodingheader*)&(myMsg->payload);
    //     // linkstateheader* LSA = (linkstateheader*)&(header->payload);
    //     uint8_t* payload = header->payload;
    //     bool finished = FALSE;
    //     bool found = FALSE;

    //     dbg(ROUTING_CHANNEL, "RECEIVED PACKET %i FROM %i\n", header->seq, header->floodsrc);
    //     dbg(FLOODING_CHANNEL, "TTL: %i, Src: %i, Dest: %i, Floodsrc: %i, Seq: %i, ", header->TTL, myMsg->src, myMsg->dest, header->floodsrc, header->seq);
    //     // if(call Flooding.flood(myMsg) == SUCCESS)
    //     // {
    //         for(i = 0; i < TABLE_CACHE_SIZE; i++)
    //         {
    //             if(cache[i].floodsrc == header->floodsrc)
    //             {
    //                 if((cache[i].received + 1)*FLOODING_MAX_PAYLOAD_SIZE < sizeof(Neighbor)*MAX_NEIGHBOR)
    //                 {
    //                     memcpy((&cache[i].table) + cache[i].received*FLOODING_MAX_PAYLOAD_SIZE, payload, FLOODING_MAX_PAYLOAD_SIZE);
    //                     cache[i].received++;
    //                 }
    //                 else
    //                 {
    //                     memcpy((&cache[i].table) + cache[i].received*FLOODING_MAX_PAYLOAD_SIZE, payload, sizeof(Neighbor)*MAX_NEIGHBOR - cache[i].received*FLOODING_MAX_PAYLOAD_SIZE);
    //                     cache[i].received++;
    //                     finished = TRUE;
    //                 }
    //                 found = TRUE;
    //                 break;
    //             }
    //         }
    //         if(found == FALSE)
    //         {
    //             TableCache update;
    //             update.floodsrc = header->floodsrc;
    //             update.received = 1;
    //             memcpy(&update.table, payload, LINKSTATE_MAX_PAYLOAD_SIZE);
    //             cache[cachePointer++] = update;

    //             dbg(ROUTING_CHANNEL, "NEW TABLE CACHE FOR %i!\n", header->floodsrc);
    //         }
    //         // After processing payload,
    //         // Parse and send the data
    //         for(i = 0; i < sizeof(Neighbor)*MAX_NEIGHBOR - LINKSTATE_MAX_PAYLOAD_SIZE; i = i + LINKSTATE_MAX_PAYLOAD_SIZE)
    //         {
    //             memcpy(&payload, &table + i, LINKSTATE_MAX_PAYLOAD_SIZE);
    //             // myMsg->src = TOS_NODE_ID;
    //             call Flooding.flood(myMsg);
    //         }
    //         memcpy(&payload, &table + i, sizeof(Neighbor)*MAX_NEIGHBOR - i);
    //         call Flooding.flood(myMsg);
    //     // }
    //     // call Flooding.flood(myMsg);
    // }

    command void Routing.forward(uint16_t destination, uint8_t* payload)
    {
        dbg(ROUTING_CHANNEL, "Forwarding\n");
    }

    command void Routing.printLinkState()
    {
        dbg(ROUTING_CHANNEL, "DEST   TO   COST   ALT   ALTCOST\n");
        for(i = 0; i < MAX_ROUTING; i++)
        {
            if(table[i].dest != 0)
            dbg_clear(ROUTING_CHANNEL, "                              %02i   %02i    %03i    %02i    %03i\n", table[i].dest, table[i].to, table[i].cost, table[i].toAlt, table[i].costAlt);
        }
    }

    command void Routing.calculateSP()
    {
        dijkstra();
    }

    void dijkstra()
    {
        Route update;
        tablePointer = 0;

        update.dest = 0;
        for(i = 0; i < MAX_ROUTING; i++)
        {
            update.dest = i+1;
            update.to = 0;
            if() update.cost = INFINITY;
            update.toAlt = 0;
            update.costAlt = INFINITY;
            table[tablePointer++] = update;
        }
        update.dest = TOS_NODE_ID;
        update.to = 0;
        update.cost = 0;
        update.toAlt = 0;
        update.costAlt = INFINITY;
        table[TOS_NODE_ID - 1] = update;
        
        while(1 == 1)
        {
            bool unconsidered = TRUE
            for(i == 0; i < MAX_ROUTING; i++)
            {
                if(linkStates[i].considered == TRUE) unconsidered = FALSE;
            }
            if(unconsidered == FALSE) break;


        }
        // for(i = 0; i < MAX_NEIGHBOR; i++)
        // {
        //     if(neighborTable[i].active == TRUE)
        //     if(linkStates[i].considered == FALSE)
        //     {

        //     }
        // }

    }

    void isNeighbor(uint16_t NODE_ID)
    {
        for(i = 0; i < neighborCount; i++)
        {
            if(neighborTable[i].address == NODE_ID) return TRUE;
        }
        return FALSE;
    }
}
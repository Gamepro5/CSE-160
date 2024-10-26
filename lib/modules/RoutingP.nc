module RoutingP
{
    provides interface Routing;
    uses interface NeighborDiscovery;
    uses interface Flooding;

    uses interface Timer<TMilli> as waitTimer;
    uses interface Timer<TMilli> as reCalcTimer;
    uses interface SimpleSend as Sender;
}

implementation
{
    void dijkstra();
    bool isActiveNeighbor(uint16_t NODE_ID);
    void addToCache(pack* Package, bool sentAlt);
    
    Neighbor neighborTable[MAX_NEIGHBOR];
    uint8_t neighborCount;
    LinkState linkStates[MAX_ROUTING];
    Route table[MAX_ROUTING];
    TableCache cache[TABLE_CACHE_SIZE];
    uint8_t tablePointer = 0;
    uint8_t cachePointer = 0;
    bool initialized = FALSE;
    int TIMER_INTERVAL = 5000; 
    uint16_t sequenceNum = 0;
    bool builtRoutingTable = FALSE;

    pack_cache sentCache[FLOOD_CACHE_SIZE];    
    uint8_t writeSentCache = 0;
    uint8_t readSentCache = 0;

    pack sendPackage;
    int i;

    command void Routing.init()
    {
        // call waitTimer.startOneShot(15000);
    }

    event void reCalcTimer.fired()
    {
        dijkstra();
    }

    event void waitTimer.fired()
    {
        dbg(ROUTING_CHANNEL, "Send timer expired: ");
        // dbg_clear(ROUTING_CHANNEL, "Testing \"%s\" to %i\n", sentCache[readSentCache].payload, sentCache[readSentCache].dest);

        // If the node is stil looking for a reply
        if(sentCache[readSentCache].received == 0)
        { 
            if(sentCache[readSentCache].sentAlt == TRUE) dbg_clear(ROUTING_CHANNEL, "Alt route failed!\n");
            else
            {
                uint16_t forward;
                dbg_clear(ROUTING_CHANNEL, "Resending \"%s\" to %i\n", sentCache[readSentCache].payload, sentCache[readSentCache].dest);
                
                if(sentCache[readSentCache].sentAlt == TRUE && table[sentCache[readSentCache].dest-1].toAlt == 0) forward = table[sentCache[readSentCache].dest-1].to;
                else forward = table[sentCache[readSentCache].dest-1].toAlt;
                
                // Reflood the packet with an increased sequence number
                makeRoutePack(&sendPackage, TOS_NODE_ID, sentCache[readSentCache].dest, PROTOCOL_FLOODING, MAX_TTL, sequenceNum++, &sentCache[readSentCache].payload);
                call Sender.send(sendPackage, forward);

                // Cache this packet sent, so when this node receives, it doesn't continue the flood
                addToCache(&sendPackage, TRUE);
                
                // Restart the timer
                call waitTimer.startOneShot(TIMER_INTERVAL);
            }   
        }
        // Otherwise if not looking for a reply
        else if(sentCache[readSentCache].dest == AM_BROADCAST_ADDR) dbg_clear(FLOODING_CHANNEL, "Not expecting a reply...\n");
        else dbg_clear(ROUTING_CHANNEL, "Reply was received, terminating...\n");
        if(++readSentCache == FLOOD_CACHE_SIZE) readSentCache = 0;
    }

    event void NeighborDiscovery.updateNeighbors(void* data, uint8_t len, uint8_t count)
    {
        memcpy(&neighborTable, data, len);
        neighborCount = count;
        // if(builtRoutingTable == TRUE) call Routing.floodLinkState();
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
        // dbg(ROUTING_CHANNEL, "STARTING LINKSTATE FLOOD\n");
        
        i = 0;
        while(i < neighborCount)
        {
            int j;
            uint8_t payload[FLOODING_MAX_PAYLOAD_SIZE];
            uint16_t* writeToPayload = &payload;
            
            // dbg(ROUTING_CHANNEL, "BEGIN WHILE LOOP\n");

            for(j = 0; j < FLOODING_MAX_PAYLOAD_SIZE/2; j++)
            {
                // dbg(ROUTING_CHANNEL, "BEGIN FOR LOOP J=%i\n", j);
                
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
            //copy my neighbors into the payload.
            memcpy(linkStates[TOS_NODE_ID - 1].neighbors, &payload, FLOODING_MAX_PAYLOAD_SIZE - 1);

            // dbg(ROUTING_CHANNEL, "INIT FLOOD\n");
            call Flooding.startFlood(AM_BROADCAST_ADDR, &payload, PROTOCOL_LINK_STATE);
        }
        dbg(ROUTING_CHANNEL, "LINKSTATE FLOODED\n");
    }
    
    command void Routing.receivedLinkStatePacket(pack* myMsg)
    {
        pack myMsgCopy = *myMsg;
        floodingheader* header = (floodingheader*)&(myMsgCopy.payload);
        uint16_t* payload = header->payload;

        dbg(ROUTING_CHANNEL, "RECEIVED %sLINK STATE FROM %i: ", (header->payload[FLOODING_MAX_PAYLOAD_SIZE - 1] == 1) ? "LAST " : "", header->floodsrc);

        if(call Flooding.flood(myMsg) == SUCCESS)
        {   
            
            if(linkStates[header->floodsrc - 1].receivedFirst == FALSE)
            {
                linkStates[header->floodsrc - 1].firstReceived = header->seq;
                linkStates[header->floodsrc - 1].lastReceived = header->seq;
                linkStates[header->floodsrc - 1].receivedFirst == TRUE;
            }
            
            else if(header->seq == 0 && linkStates[header->floodsrc - 1].lastReceived != 0)
            {
                linkStates[header->floodsrc - 1].offset = linkStates[header->floodsrc - 1].lastReceived - linkStates[header->floodsrc - 1].firstReceived + 1;
            }

            //recontsruct the packet (since sending the enire packet is too large)
            for(i = 0; i < FLOODING_MAX_PAYLOAD_SIZE/2; i++)
            {
                uint16_t target;
                if(linkStates[header->floodsrc - 1].offset == 0) target = linkStates[header->floodsrc - 1].lastReceived - linkStates[header->floodsrc - 1].firstReceived;
                else target = linkStates[header->floodsrc - 1].offset + header->seq;

                dbg_clear(ROUTING_CHANNEL, "%u, ", *(payload + i));
                
                linkStates[header->floodsrc - 1].lastReceived = header->seq;
                if(i+target < MAX_NEIGHBOR) linkStates[header->floodsrc - 1].neighbors[i+target*FLOODING_MAX_PAYLOAD_SIZE/2] = *(payload + i);
            }
            // i+(linkStates[header->floodsrc - 1].firstReceived - header->seq)*(FLOODING_MAX_PAYLOAD_SIZE/2)
            if(header->payload[FLOODING_MAX_PAYLOAD_SIZE - 1] == 1) linkStates[header->floodsrc - 1].receivedFirst = FALSE;
        }
        else dbg_clear(ROUTING_CHANNEL, "Packet seen before, dropping...");
        dbg_clear(ROUTING_CHANNEL, "\n");

        // if(builtRoutingTable == TRUE) call reCalcTimer.startOneShot(15000);
    }

    command void Routing.forward(pack* myMsg)
    {
        routingheader* header = (routingheader*)&(myMsg->payload);

        if(myMsg->dest == TOS_NODE_ID)
        {
            if(myMsg->protocol == PROTOCOL_ROUTING_REPLY)
            {
                dbg(ROUTING_CHANNEL, "Payload received from %i: \"%s\"\n", myMsg->src, header->payload);
                for(i = 0; i < FLOOD_CACHE_SIZE; i++)
                {
                    if(sentCache[i].seq == header->seq && sentCache[i].dest == myMsg->src);
                    {
                        sentCache[i].received = 1;
                        break;
                    }
                }
                return;
            }
            else
            {
                uint8_t* payload = "ACK";
                dbg(ROUTING_CHANNEL, "Payload received from %i: \"%s\"\n", myMsg->src, header->payload);
                // dbg(ROUTING_CHANNEL, "Sending \"%s\" to %i. Forwarding to %i..\n", payload, myMsg->src, table[myMsg->src-1].to);

                makeRoutePack(&sendPackage, TOS_NODE_ID, myMsg->src, PROTOCOL_ROUTING_REPLY, MAX_TTL, header->seq, payload);
                call Routing.forward(&sendPackage);
                
                // Probably redundant but I just wanted to be safe
                if(sequenceNum == 65535) sequenceNum = 0;

                return;
            }
        }
        else if(myMsg->src == TOS_NODE_ID)
        {
            dbg(ROUTING_CHANNEL, "Sending \"%s\" to %i. Forwarding to %i..\n", header->payload, myMsg->dest, table[myMsg->dest-1].to);
            header->seq = sequenceNum++;
            addToCache(&sendPackage, FALSE);
            if(myMsg->protocol == PROTOCOL_ROUTING) call waitTimer.startOneShot(TIMER_INTERVAL);
        }
        else dbg(ROUTING_CHANNEL, "Src: %i, Dest: %i, Forwarding to %i..\n", myMsg->src, myMsg->dest, table[myMsg->dest-1].to);
        
        call Sender.send(*myMsg, table[myMsg->dest-1].to);
    }

    // Prints routing tables
    command void Routing.printRoutingTable()
    {
        dbg(ROUTING_CHANNEL, "DEST   TO   COST   ALT   ALTCOST\n");
        for(i = 0; i < MAX_ROUTING; i++)
        {
            if(table[i].dest != 0)
            dbg_clear(ROUTING_CHANNEL, "                              %02i   %02i    %03i    %02i    %03i\n", table[i].dest, table[i].to, table[i].cost, table[i].toAlt, table[i].costAlt);
            // Printing used for linkStates cache
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
        builtRoutingTable = FALSE;

        // For each row in the routing table
        for(i = 0; i < MAX_ROUTING; i++)
        {
            // Initialization for self in table
            if(i+1 == TOS_NODE_ID)
            {
                update.dest = TOS_NODE_ID;
                update.to = 0;
                update.cost = 0;
                update.toAlt = 0;
                update.costAlt = 0;
                update.considered = TRUE;
            }
            // Initialization for all neighbors in table
            else if(isActiveNeighbor(i+1) == TRUE)
            {
                update.dest = i+1;
                update.to = i+1;
                update.cost = 1;
                update.toAlt = 0;
                update.costAlt = INFINITY;
                update.considered = FALSE;
            }
            // Initialization for every other node
            else
            {
                update.dest = i+1;
                update.to = 0;
                update.cost = INFINITY;
                update.toAlt = 0;
                update.costAlt = INFINITY;
                update.considered = FALSE;
            }
            // Update table location
            table[i] = update;
        }
        
        // Loop forever until all nodes are considered
        while(1 == 1)
        {
            // Index for underConsideration undiscovered node is set to INFINITY as default
            uint8_t underConsideration = INFINITY;
            
            // All nodes are considered until one is found that is NOT considered
            bool allNodesConsidered = TRUE;
            // The for loop iterates through all nodes and when it comes across an unconsidered node,
            // Set allNodesConsidered to false and break
            for(i = 0; i < MAX_ROUTING; i++)
            {
                if(table[i].considered == FALSE)
                {
                    allNodesConsidered = FALSE;
                    break;
                }
            }
            // If all nodes are considered, break from the forever loop
            if(allNodesConsidered == TRUE) break;
            
            // For loop looks for an unconsidered node with the lowest cost
            // And it the index of the lowest cost node is stored in underConsideration
            for(i = 0; i < MAX_ROUTING; i++)
            {
                if(table[i].considered == TRUE){}
                else if(underConsideration == (uint8_t)INFINITY) underConsideration = i;
                else if(table[i].cost < table[underConsideration].cost) underConsideration = i;
            }

            // For each neighbor of the unconsidered node with the lowest cost,
            for(i = 0; i < MAX_NEIGHBOR; i++)
            {
                // Current is defined as the address of the neighborOfUnderConsideration neighbor node
                // of the lowest cost unconsidered node being evaluated
                uint16_t neighborOfUnderConsideration = linkStates[underConsideration].neighbors[i];
                // uint16_t neighborOfUnderConsideration = i+1;

                // If the neighbor address is NOT 0 and the neighbor's currently defined TO
                // Is NOT the same as the TO for underConsideration
                if(neighborOfUnderConsideration != 0 && table[neighborOfUnderConsideration-1].to != table[underConsideration].to)
                {
                    dbg(ROUTING_CHANNEL, "Calculating new cost for %i from %i... \n", neighborOfUnderConsideration, underConsideration+1);
                    
                    // If the suggested cost is lower than the cost already recorded
                    if(table[underConsideration].cost + 1 < table[neighborOfUnderConsideration-1].cost)
                    {
                        // Move to and cost to alt storage
                        table[neighborOfUnderConsideration-1].costAlt = table[neighborOfUnderConsideration-1].cost;
                        table[neighborOfUnderConsideration-1].toAlt = table[neighborOfUnderConsideration-1].to;

                        // Update to and cost with new suggested cost/to
                        table[neighborOfUnderConsideration-1].cost = table[underConsideration].cost + 1;
                        table[neighborOfUnderConsideration-1].to = table[underConsideration].to;
                    }
                    // Otherwise if the suggested cost is lower than the alt cost already recorded
                    else if(table[underConsideration].cost + 1 < table[neighborOfUnderConsideration-1].costAlt)
                    {
                        // Update alt to and cost with new suggested cost/to
                        table[neighborOfUnderConsideration-1].costAlt = table[underConsideration].cost + 1;
                        table[neighborOfUnderConsideration-1].toAlt = table[underConsideration].to;
                    }
                }
            }
            // Mark the under consideration as considered
            table[underConsideration].considered = TRUE;
        }
        builtRoutingTable = TRUE;
    }

    // Returns whether node is an active neighbor or not
    bool isActiveNeighbor(uint16_t NODE_ID)
    {
        int j;
        for(j = 0; j < neighborCount; j++)
        {
            if(neighborTable[j].address == NODE_ID)
            {
                if(neighborTable[j].active == TRUE) return TRUE;
                else return FALSE;
            }
        }
        return FALSE;
    }

    // Command that adds record to pack cache
    void addToCache(pack* Package, bool sentAlt)
    {
        routingheader* header = (routingheader*)&(Package->payload);
        pack_cache update;

        update.src = Package->src;
        update.seq = header->seq;
        update.dest = Package->dest;
        update.received = 0;
        update.sentAlt = sentAlt;
        memcpy(&update.payload, header->payload, ROUTING_MAX_PAYLOAD_SIZE);
        // dbg(ROUTING_CHANNEL, "Updated cache at index %i with Src: %i, Dest: %i, Seq: %i, \"%s\"\n", update.src, update.dest, update.seq, update.payload);
        sentCache[writeSentCache] = update;
        if(++writeSentCache == FLOOD_CACHE_SIZE) writeSentCache = 0;
    }
}
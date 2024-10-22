module FloodingP
{
    provides interface Flooding;
    uses interface Timer<TMilli> as waitTimer;
    uses interface SimpleSend as Sender;
    uses interface NeighborDiscovery;
}

implementation
{
    uint8_t i;                                  // Global iterator
    bool duplicatePacket = FALSE;               // Keeps track of whether a duplicate packet has been received
    uint16_t sequenceNum = 0;                   // Sequence
    Neighbor neighborTable[MAX_NEIGHBOR];       // Neighbor table
    int TIMER_INTERVAL = 7500;                  // in milliseconds

    flood_cache packetCache[FLOOD_CACHE_SIZE];  // Keeps a record of packets sent/received
    uint8_t lastUpdatedPacketCacheSlot = 0;     // Keeps track of where in the array to write to next
    
    flood_cache sentCache[FLOOD_CACHE_SIZE];    
    uint8_t writeSentCache = 0;
    uint8_t readSentCache = 0;
    
    pack sendPackage;                           // Space used to write and send a package
    
    // Event triggers when neighbors are updated in Neighbor Discovery module
    event void NeighborDiscovery.updateNeighbors(void* data, uint8_t len, uint8_t count)
    {
        memcpy(&neighborTable, data, len);
    }

    // Wait timer for flooding
    event void waitTimer.fired()
    {
        dbg(FLOODING_CHANNEL, "Flood timer expired: ");
        
        // If the node is stil looking for a reply
        if(sentCache[readSentCache].received == 0 && sentCache[readSentCache].dest != AM_BROADCAST_ADDR)
        { 
            dbg_clear(FLOODING_CHANNEL, "Initiating Flood Packet %i for %i: \"%s\"\n", sequenceNum, sentCache[readSentCache].dest, sentCache[readSentCache].payload);
            
            // Reflood the packet with an increased sequence number
            makeFloodPack(&sendPackage, TOS_NODE_ID, sentCache[readSentCache].dest, PROTOCOL_FLOODING, TOS_NODE_ID, MAX_TTL, sequenceNum++, 0, &sentCache[readSentCache].payload);
            call Sender.send(sendPackage, AM_BROADCAST_ADDR);

            // Cache this packet sent, so when this node receives, it doesn't continue the flood
            call Flooding.addToCache(&sendPackage);

            // Restart the timer
            call waitTimer.startOneShot(TIMER_INTERVAL);
        }
        // Otherwise if not looking for a reply
        else if(sentCache[readSentCache].dest == AM_BROADCAST_ADDR) dbg_clear(FLOODING_CHANNEL, "Not expecting a reply...\n");
        else dbg_clear(FLOODING_CHANNEL, "Reply was received, terminating...\n");
        if(++readSentCache == FLOOD_CACHE_SIZE) readSentCache = 0;
    }

    // Source node broadcasts a flood packet
    command void Flooding.startFlood(uint16_t destination, uint8_t* payload, int protocol)
    {
        dbg(FLOODING_CHANNEL, "Initiating Flood Packet %i for %i: \"%s\"\n", sequenceNum, destination, payload);
        
        // Make the flood packet and broadcast it to anyone that can listen
        makeFloodPack(&sendPackage, TOS_NODE_ID, destination, protocol, TOS_NODE_ID, MAX_TTL, sequenceNum++, 0, payload);
        
        // For each neighbor in the table
        for(i = 0; i < MAX_NEIGHBOR; i++)
        {
            // If the neighbor is active
            if(neighborTable[i].active == TRUE)
            {
                // Send the neighbor the packet
                // dbg_clear(FLOODING_CHANNEL, "%i..", neighborTable[i].address);
                call Sender.send(sendPackage, neighborTable[i].address);
            }
        }
        // dbg_clear(FLOODING_CHANNEL, "\n");
        
        // Cache this packet sent, so when this node receives, it doesn't continue the flood
        call Flooding.addToCache(&sendPackage);
        
        // Start the wait timer,
        call waitTimer.startOneShot(TIMER_INTERVAL);
        
        // Probably redundant but I just wanted to be safe
        if(sequenceNum == 65535) sequenceNum = 0;
    }

    // // When a node receives a flood packet
    command error_t Flooding.flood(pack* myMsg)
    {    
        // Unpack the flooding header
        floodingheader* header = (floodingheader*)&(myMsg->payload);
        
        if(myMsg->protocol == PROTOCOL_FLOODING)
            dbg(FLOODING_CHANNEL, "\"%s\", TTL: %i, Src: %i, Dest: %i, Floodsrc: %i, Seq: %i, ", header->payload, header->TTL, myMsg->src, myMsg->dest, header->floodsrc, header->seq);

        // Assume the packet is not a duplicate until discovered in the flood cache
        duplicatePacket = FALSE;
        
        // For each record in the flood cache
        for(i = 0; i < FLOOD_CACHE_SIZE; i++)
        {
            // If the cached record matches the packet received
            if((packetCache[i].floodsrc == header->floodsrc && packetCache[i].seq == header->seq)
                || (sentCache[i].floodsrc == header->floodsrc && sentCache[i].seq == header->seq))
            {
                dbg_clear(FLOODING_CHANNEL, "Packet seen before, dropping...\n");
                
                // Mark packet as duplicate and break from the loop
                duplicatePacket = TRUE;
                return FAIL;
            }
        }
        
        if(duplicatePacket == FALSE)
        {
            // Caches the packet received
            call Flooding.addToCache(myMsg);

            // If the packet has reached its destination
            if(myMsg->dest == TOS_NODE_ID)
            {
                dbg_clear(FLOODING_CHANNEL, "\n");
                dbg(FLOODING_CHANNEL, "Payload %i Received from %i: \"%s\"\n", header->seq, header->floodsrc, header->payload);
                
                // If the packet is not a reply
                if(header->reply == 0) 
                {
                    // ACK payload
                    uint8_t* payload = "ACK";
                    dbg(FLOODING_CHANNEL, "Initiating Flood Packet %i for %i: \"%s\"\n", header->seq, header->floodsrc, payload);

                    // Makes the reply packet and floods, broadcasting to anyone who can listen
                    makeFloodPack(&sendPackage, TOS_NODE_ID, header->floodsrc, PROTOCOL_FLOODING, TOS_NODE_ID, MAX_TTL, header->seq, 1, payload);
                    call Sender.send(sendPackage, AM_BROADCAST_ADDR);
                    
                    // Caches the ACK sent
                    call Flooding.addToCache(&sendPackage);
                }
                // Otherwise if the packet is a reply
                else if(header->reply == 1)
                {
                    // No longer looking for a reply, the reply has been received
                    dbg(FLOODING_CHANNEL, "No longer looking for a reply\n");
                    for(i = 0; i < FLOOD_CACHE_SIZE; i++)
                    {
                        if(sentCache[i].seq == header->seq)
                        {
                            sentCache[i].received = 1;
                            break;
                        }
                    }
                }
            }
            // Otherwise if the packet has not reached its destination
            else
            {
                // dbg(FLOODING_CHANNEL, "\"%s\", TTL: %i, Src: %i, Dest: %i, Floodsrc: %i, Seq: %i, ", header->payload, header->TTL, myMsg->src, myMsg->dest, header->floodsrc, header->seq);
                // If the packet not seen before and the TTL isn't 1
                if(header->TTL-1 > 0)
                {
                    dbg_clear(FLOODING_CHANNEL, "Sending to: ");
                    // Create the flood packet to be sent
                    makeFloodPack(&sendPackage, TOS_NODE_ID, myMsg->dest, myMsg->protocol, header->floodsrc, header->TTL-1, header->seq, header->reply, header->payload);
                    
                    // For each neighbor in the table
                    for(i = 0; i < MAX_NEIGHBOR; i++)
                    {
                        // If the neighbor is active
                        if(neighborTable[i].active == TRUE)
                        {
                            // Send the neighbor the packet
                            dbg_clear(FLOODING_CHANNEL, "%i..", neighborTable[i].address);
                            call Sender.send(sendPackage, neighborTable[i].address);
                        }
                    }
                    dbg_clear(FLOODING_CHANNEL, "\n");
                }
                else
                {
                    dbg_clear(FLOODING_CHANNEL, "TTL will be 0 (dead on arrival)\n");
                }
            }
        }
        return SUCCESS;
    }

    // Command that adds record to packet cache
    command void Flooding.addToCache(pack* Package)
    {
        floodingheader* header = (floodingheader*)&(Package->payload);
        flood_cache update;

        update.floodsrc = header->floodsrc;
        update.seq = header->seq;
        update.dest = Package->dest;
        if(TOS_NODE_ID == update.floodsrc)
        {
            update.received = 0;
            // update.payload = header->payload;
            memcpy(&update.payload, &header->payload, FLOODING_MAX_PAYLOAD_SIZE);
            sentCache[writeSentCache++] = update;
            if(writeSentCache == FLOOD_CACHE_SIZE) writeSentCache = 0;
        }
        else
        {
            uint8_t dummyPayload[FLOODING_MAX_PAYLOAD_SIZE] = "";
            update.received = 1;
            memcpy(&update.payload, &dummyPayload, FLOODING_MAX_PAYLOAD_SIZE);
            packetCache[lastUpdatedPacketCacheSlot++] = update;
            // If the index has reached the end of the table, move to the beginning
            if(lastUpdatedPacketCacheSlot == FLOOD_CACHE_SIZE) lastUpdatedPacketCacheSlot = 0;
        }
    }

    // // Command that adds record to cache
    // command void Flooding.addToSentCache(uint16_t floodsrc, uint16_t seq, uint8_t* payload)
    // {
    //     // Creates an update record to be put into the table
    //     flood_cache update;
    //     update.floodsrc = floodsrc;
    //     update.seq = seq;
    //     if(TOS_NODE_ID == floodsrc) update.received = 0;
    //     else update.received = 1;
    //     packetCache[lastUpdatedPacketCacheSlot++] = update;

    //     // If the index has reached the end of the table, move to the beginning
    //     if(lastUpdatedPacketCacheSlot == MAX_NEIGHBOR) lastUpdatedPacketCacheSlot = 0;
    // }
}
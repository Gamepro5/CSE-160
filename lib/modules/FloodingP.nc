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
    bool lookingForReply = FALSE;               // Keeps track of if the node is looking for a reply (in other words if it's busy)
    bool duplicatePacket = FALSE;               // Keeps track of whether a duplicate packet has been received
    uint16_t sequenceNum = 0;                   // Sequence
    flood_cache packetCache[FLOOD_CACHE_SIZE];  // Keeps a record of packets sent/received
    uint8_t lastUpdatedPacketCacheSlot = 0;     // Keeps track of where in the array to write to next
    Neighbor neighborTable[MAX_NEIGHBOR];       // Neighbor table
    int TIMER_INTERVAL = 7500;                  // in milliseconds
    uint8_t firingCount = 0;
    
    pack sendPackage;                           // Space used to write and send a package
    pack resendPackage;                         // Space used to store the package to be resent if not received before the timer fires
    
    // Event triggers when neighbors are updated in Neighbor Discovery module
    event void NeighborDiscovery.updateNeighbors(void* data, uint8_t len)
    {
        memcpy(neighborTable, data, len);
    }

    // Wait timer for flooding
    event void waitTimer.fired()
    {
        dbg(FLOODING_CHANNEL, "Flood timer expired:\n");
        
        // If the node is stil looking for a reply
        if(lookingForReply == TRUE)
        {
            if(++firingCount < 5)
            {
                // Extracts the header from the payload
                floodingheader* header = (floodingheader*)&(resendPackage.payload);
                
                dbg(FLOODING_CHANNEL, "Initiating Flood Packet %i for %i: \"%s\"\n", sequenceNum, resendPackage.dest, header->payload);
                
                // Reflood the packet with an increased sequence number
                header->seq = sequenceNum++;
                call Sender.send(resendPackage, AM_BROADCAST_ADDR);

                // Restart the timer
                call waitTimer.startOneShot(TIMER_INTERVAL);
            }
            else
            {
                dbg(FLOODING_CHANNEL, "Aborted after %i attempts\n", firingCount);
                firingCount = 0;
            }
        }
        // Otherwise if not looking for a reply
        else dbg(FLOODING_CHANNEL, "Reply was received, terminating...\n");
    }

    // Source node broadcasts a flood packet
    command void Flooding.startFlood(uint16_t destination, uint8_t* payload)
    {
        // If the node isn't busy flooding
        if(lookingForReply == FALSE)
        {
            dbg(FLOODING_CHANNEL, "Initiating Flood Packet %i for %i: \"%s\"\n", sequenceNum, destination, payload);
            
            // Cache this packet being sent, so when this node receives, it doesn't continue the flood
            call Flooding.addToCache(TOS_NODE_ID, sequenceNum);
            
            // Make the flood packet and broadcast it to anyone that can listen
            makeFloodPack(&sendPackage, TOS_NODE_ID, destination, PROTOCOL_FLOODING, TOS_NODE_ID, MAX_TTL, sequenceNum++, 0, payload);
            call Sender.send(sendPackage, AM_BROADCAST_ADDR);
            
            // Start the wait timer,
            call waitTimer.startOneShot(TIMER_INTERVAL);
            // Mark as lookingForReply to indicate it's busy
            lookingForReply = TRUE;
            // And store a copy of the packet
            resendPackage = sendPackage;
            
            // Probably redundant but I just wanted to be safe
            if(sequenceNum == 65535) sequenceNum = 0;
        }
        // Otherwise if the node is busy, abort flooding
        else dbg(FLOODING_CHANNEL, "Failed to Flood Packet for %i: \"%s\" (Reason: line busy)\n", destination, payload);
    }

    // // When a node receives a flood packet
    command void Flooding.flood(pack* myMsg)
    {    
        // Unpack the flooding header
        floodingheader* header = (floodingheader*)&(myMsg->payload);
        
        dbg(FLOODING_CHANNEL, "\"%s\", TTL: %i, Src: %i, Dest: %i, Floodsrc: %i, Seq: %i, ", header->payload, header->TTL, myMsg->src, myMsg->dest, header->floodsrc, header->seq);

        // Assume the packet is not a duplicate until discovered in the flood cache
        duplicatePacket = FALSE;
        
        // For each record in the flood cache
        for(i = 0; i < FLOOD_CACHE_SIZE; i++)
        {
            // If the cached record matches the packet received
            if(packetCache[i].floodsrc == header->floodsrc && packetCache[i].seq == header->seq)
            {
                dbg_clear(FLOODING_CHANNEL, "Packet seen before, dropping...\n");
                
                // Mark packet as duplicate and break from the loop
                duplicatePacket = TRUE;
                break;
            }
        }
        
        if(duplicatePacket == FALSE)
        {
            // Caches the packet received
            call Flooding.addToCache(header->floodsrc, header->seq);

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
                    
                    // Caches the ACK to be sent
                    call Flooding.addToCache(TOS_NODE_ID, header->seq);

                    // Makes the reply packet and floods, broadcasting to anyone who can listen
                    makeFloodPack(&sendPackage, TOS_NODE_ID, header->floodsrc, PROTOCOL_FLOODING, TOS_NODE_ID, MAX_TTL, header->seq, 1, payload);
                    call Sender.send(sendPackage, AM_BROADCAST_ADDR);
                }
                // Otherwise if the packet is a reply
                else if(header->reply == 1)
                {
                    // No longer looking for a reply, the reply has been received
                    dbg(FLOODING_CHANNEL, "No longer looking for a reply\n");
                    lookingForReply = FALSE;
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
                    makeFloodPack(&sendPackage, TOS_NODE_ID, myMsg->dest, PROTOCOL_FLOODING, header->floodsrc, header->TTL-1, header->seq, header->reply, header->payload);
                    
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
    }

    // Command that adds record to cache
    command void Flooding.addToCache(uint16_t floodsrc, uint16_t seq)
    {
        // Creates an update record to be put into the table
        flood_cache update;
        update.floodsrc = floodsrc;
        update.seq = seq;
        update.receivedReply = 0;
        packetCache[lastUpdatedPacketCacheSlot++] = update;

        // If the index has reached the end of the table, move to the beginning
        if(lastUpdatedPacketCacheSlot == MAX_NEIGHBOR) lastUpdatedPacketCacheSlot = 0;
    }
}
module NeighborDiscoveryP
{
    provides interface NeighborDiscovery;
    
    uses interface Timer<TMilli> as discoveryTimer;
    uses interface SimpleSend as Sender;
}

implementation
{
    Neighbor table[MAX_NEIGHBOR];
    uint8_t tablePointer = 0;
    uint16_t sequenceNum = 0;       // initial sequence number
    int TIMER_INTERVAL = 800;       // in milliseconds
    float alpha = 0.75;             // alpha for EWMA (between 0 and 1)
    float activeCutoff = 0.25;      // cutoff percentage for determining whether a node is really a neighbor
    uint8_t i;                      // global iterator
    bool newNeighbor;               // keeps track of whether a neighbor is found in the table or not

    pack sendPackage;

    // Initialization of Neighbor Discovery module
    command void NeighborDiscovery.init()
    {
        // Creates a "null" neighbor to take up space in the table
        Neighbor null;
        null.address = 0;
        null.quality = 0;
        null.active = FALSE;
        null.received = 0;
        null.lastSeq = 0;
        
        // For each index in the neighbor table, make it default (null)
        for(i = 0; i < MAX_NEIGHBOR; i++) table[i] = null;
        
        // Broadcast discovery packet looking for neighbors
        call NeighborDiscovery.broadcast();
        
        // Initialize discovery timer
        call discoveryTimer.startPeriodic(TIMER_INTERVAL);
    }

    // Neighbor Discovery Timer
    event void discoveryTimer.fired()
    {
        // Boolean to keep track of if an update has occured to the table
        bool updated = FALSE;
        // For each neighbor in the table
        for(i = 0; i < MAX_NEIGHBOR; i++)
        {
            // If the address is valid (not 0)
            if(table[i].address != 0)
            {
                // Calculate the link quality
                table[i].quality = alpha * table[i].received + (1 - alpha) * table[i].quality;
                // If the quality is equal to or above the cutoff threshold
                if(table[i].quality >= activeCutoff)
                {
                    // If the neighbor isn't active
                    if(table[i].active == FALSE)
                    {
                        // Make it active and mark the table as updated
                        updated = TRUE;
                        table[i].active = TRUE;
                    } 
                }
                // Otherwise if the quality is below the cutoff threshold
                else
                {
                    // If the neighbor is active
                    if(table[i].active == TRUE)
                    {
                        // Make it inactive and mark the table as updated
                        updated = TRUE;
                        table[i].active = FALSE;
                    }
                }
                // Resets the received value to 0 for next discovery interval
                if(table[i].received == 1) table[i].received = 0;
            }
            // If the table was updated, signal the updated neighbor table to other modules
            if(updated == TRUE) signal NeighborDiscovery.updateNeighbors(&table, sizeof(Neighbor)*MAX_NEIGHBOR);
        }
        // Rebroadcast neighbor discovery packets
        call NeighborDiscovery.broadcast();
    }

    // Function for broadcasting a packet
    command void NeighborDiscovery.broadcast()
    {
        dbg(NEIGHBOR_CHANNEL, "LOOKING FOR NEIGHBORS (Seq: %i)\n", sequenceNum);
        // Makes a discovery packet and sends it
        makeDiscoveryPack(&sendPackage, TOS_NODE_ID, AM_BROADCAST_ADDR, PROTOCOL_NEIGHBOR_DISCOVERY, sequenceNum++, 0);
        call Sender.send(sendPackage, AM_BROADCAST_ADDR);
        
        // Probably redundant but I just wanted to be safe
        if(sequenceNum == 65536) sequenceNum = 0;
    }

    // Runs when a packet is received by the AM radio
    command void NeighborDiscovery.received(pack* myMsg)
    {
        // Extracts the header from the payload
        discoveryheader* header = (discoveryheader*)&(myMsg->payload);
        // Assume the packet received is from a new neighbor (will be figured out later on)
        newNeighbor = TRUE;

        // If the packet is not a reply
        if(header->reply == 0)
        {   
            dbg(NEIGHBOR_CHANNEL, "RECEIVED REQUEST %i FROM %i\n", header->seq, myMsg->src);
            // Make a discovery packet and send it directly to the source of the request
            makeDiscoveryPack(&sendPackage, TOS_NODE_ID, myMsg->src, PROTOCOL_NEIGHBOR_DISCOVERY, header->seq, 1);
            call Sender.send(sendPackage, myMsg->src);
        }
        // Otherwise if the packet is a reply
        else if(header->reply == 1)
        {
            dbg(NEIGHBOR_CHANNEL, "RECEIVED REPLY %i FROM %i\n", header->seq, myMsg->src);
            // For each neighbor in the table
            for(i = 0; i < MAX_NEIGHBOR; i++)
            {
                // If the address is already saved in the table
                if(table[i].address == myMsg->src)
                {
                    // Set to received and the last sequence number received
                    table[i].received = 1;
                    table[i].lastSeq = header->seq;
                    
                    // The packet received was not from a new neighbor so set to FALSE
                    // And break from the loop since we are done searching the table
                    newNeighbor = FALSE;
                    break;
                }
            }
            // If the neighbor wasn't recorded in the table
            if(newNeighbor == TRUE)
            {
                // Create an update record and store it in the table
                Neighbor update;
                update.address = myMsg->src;
                update.quality = 0.5;
                update.active = TRUE;
                update.received = 1;
                update.lastSeq = header->seq;
                table[tablePointer++] = update;
                
                // If the table pointer reached the end of the table, nove to beginning
                if(tablePointer >= MAX_NEIGHBOR) tablePointer = 0;
            }
        }
    }

    // Command returns neighbors when called
    // (Used only when directly requesting neighbor table and NOT for updating changes)
    command void* NeighborDiscovery.getNeighbors(Neighbor* dest) {
        return memcpy(dest, &table, sizeof(Neighbor)*MAX_NEIGHBOR);
    }

    // Prints neighbors that have been recorded to the table
    command void NeighborDiscovery.printNeighbors()
    {
        // Prints table header
        dbg(GENERAL_CHANNEL, "ADDR   QUALITY   ACTIVE\n");
        // For each neighbor in the table
        for(i = 0; i < MAX_NEIGHBOR; i++)
        {
            // If the address is valid
            if(table[i].address != 0)
            {
                // Print table record
                dbg_clear(GENERAL_CHANNEL, "                              %02d    %f  %s\n", table[i].address, table[i].active ? "true" : "false", table[i].quality);
            }
        }
    }
}

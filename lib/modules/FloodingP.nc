#include "../../includes/flood_cache.h"

module FloodingP{
    provides interface Flooding;
    uses interface Timer<TMilli> as startDelayTimer;
    uses interface SimpleSend as Sender;
    uses interface NeighborDiscovery;
}

implementation {
    //prototype
    void makePack(pack *Package, uint16_t src, uint16_t dest, uint16_t TTL, uint16_t protocol, uint16_t seq, uint8_t* payload, uint8_t length);

    // Module variables
    flood_cache packetCache[20] = {0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0}; 
    int lastUpdatedPacketCacheSlot = 0;
    int START_DELAY = 2.5; //seconds
    //int finalDestination = 12;
    pack sendPackage;

    // Timer needs to be implemented so that when a node sends a packet, it will start the timer
    // and if the timer expires and no acknowledgement was received, then send the flood packet again.
    event void startDelayTimer.fired() {
        int destination = AM_BROADCAST_ADDR;
        makePack(&sendPackage, TOS_NODE_ID, destination , 20, PROTOCOL_FLOODING, 0, "Hello, flooded world!", PACKET_MAX_PAYLOAD_SIZE);
        call Sender.send(sendPackage, destination );
    }

    // Source node broadcasts a flood packet
    command void Flooding.startFlood(uint16_t destination, uint8_t* payload) {
        makePack(&sendPackage, TOS_NODE_ID, destination, 20, PROTOCOL_FLOODING, 0, payload, PACKET_MAX_PAYLOAD_SIZE);
        if(call Sender.send(sendPackage, AM_BROADCAST_ADDR) == SUCCESS){
            dbg(FLOODING_CHANNEL, "Flooding node %i: %s\n", destination, payload);
        }
    }

    // When a node receives a flood packet
    command void Flooding.flood(pack* myPack) {
        flood_cache record;
        int i;
        bool duplicatePacket = FALSE;
        int max_neighbors = call NeighborDiscovery.getMaxNeighbors();
        int* neighbors = call NeighborDiscovery.getNeighbors();
        // dbg(FLOODING_CHANNEL, "Packet Source: %i, Packet Destination: %i, Packet Protocol: %i, Packet Payload: %s. ", myPack->src,myPack->dest,myPack->protocol,myPack->payload);
        
        // If the packet has reached its destination, send a reply flood packet or end the flood
        if(myPack->dest == TOS_NODE_ID){
            if(myPack->protocol == PROTOCOL_FLOODING) call Flooding.floodReply(myPack);
            if(myPack->protocol == PROTOCOL_FLOODING_REPLY) call Flooding.floodEnd(myPack);
            return;
        }

        // If the packet has been seen before, drop it
        for(i=0;i<20;i++){
            if (packetCache[i].src == myPack->src && packetCache[i].dest == myPack->dest) {
                dbg(FLOODING_CHANNEL, "I have seen this packet before and I will drop it on the floor.\n");
                duplicatePacket = TRUE;
                return;
            }
        }
        
        // Otherwise, flood the packet to all neighbors
        // Creating a record and stores it in the cache
        record.src = myPack->src;
        record.dest = myPack->dest;
        packetCache[lastUpdatedPacketCacheSlot] = record;

        // Moving the cache pointer appropriately for next time the cache needs to be written to
        lastUpdatedPacketCacheSlot += 1;
        if (lastUpdatedPacketCacheSlot > 19) {
            lastUpdatedPacketCacheSlot = 0;
        }
        dbg(FLOODING_CHANNEL, "Received flood packet, forwarding to: ");
        // And sending the node to all neighbors
        for (i=0;i<max_neighbors;i++) {
            if (neighbors[i] == 1) {
                makePack(&sendPackage, myPack->src, myPack->dest, myPack->TTL-1, myPack->protocol, myPack->seq+1, myPack->payload, PACKET_MAX_PAYLOAD_SIZE);  
                if(call Sender.send(sendPackage, i+1) == SUCCESS){
                    dbg_clear(FLOODING_CHANNEL, "%i, ", i+1);
                }
            }
        }
        dbg_clear(FLOODING_CHANNEL, "\n");
    }

    // Broadcasts a reply for the src node of a packet
    command void Flooding.floodReply(pack* myMsg){
        makePack(&sendPackage, myMsg->dest, myMsg->src, 20, PROTOCOL_FLOODING_REPLY, 0, "Acknowledgement", PACKET_MAX_PAYLOAD_SIZE);
        if (call Sender.send(sendPackage, AM_BROADCAST_ADDR) == SUCCESS){
            dbg(FLOODING_CHANNEL, "Packet received: %s\n", myMsg->payload);
        }
    }

    // Handles a reply flood packet being received
    command void Flooding.floodEnd(pack* myMsg){
        dbg(FLOODING_CHANNEL, "Packet received: %s\n", myMsg->payload);
    }


    // Function for making a packet
    void makePack(pack *Package, uint16_t src, uint16_t dest, uint16_t TTL, uint16_t protocol, uint16_t seq, uint8_t* payload, uint8_t length) {
        Package->src = src;
        Package->dest = dest;
        Package->TTL = TTL;
        Package->seq = seq;
        Package->protocol = protocol;
        memcpy(Package->payload, payload, length);
    }
}

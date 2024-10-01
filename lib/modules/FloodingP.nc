module FloodingP{
    provides interface Flooding;
    uses interface Timer<TMilli> as startDelayTimer;
    uses interface SimpleSend as Sender;
    uses interface NeighborDiscovery;
}

implementation {
//prototype
void makePack(pack *Package, uint16_t src, uint16_t dest, uint16_t TTL, uint16_t protocol, uint16_t seq, uint8_t* payload, uint8_t length);

uint8_t* packetCache[20];
int lastUpdatedPacketCacheSlot = 0;
int START_DELAY = 2.5; //seconds
//int finalDestination = 12;
pack sendPackage;

command void Flooding.boot() {
    if (TOS_NODE_ID == 1) { //only node 1 will start the flooding. this can change.
        call startDelayTimer.startOneShot(START_DELAY*1000);
    }
}

event void startDelayTimer.fired() { // a delay so that neighbor discovery has time to happen
    int destination = AM_BROADCAST_ADDR;
    makePack(&sendPackage, TOS_NODE_ID, destination , 0, PROTOCOL_FLOODING, 0, "Hello, flooded world!", PACKET_MAX_PAYLOAD_SIZE);
    call Sender.send(sendPackage, destination );
}
command void Flooding.flood(pack* myPack) {
    int i;
    bool duplicatePacket = FALSE;
    int max_neighbors = call NeighborDiscovery.getMaxNeighbors();
    int* neighbor = call NeighborDiscovery.getNeighbors();
    dbg(FLOODING_CHANNEL, "Package Sender: %i, Package Protocol: %i, Package Payload: %s\n", myPack->src,myPack->protocol,myPack->payload);
    for (i=0;i<max_neighbors;i++) {
        if (packetCache[20] == myPack->payload) {
            //drop the packet on the floor
            dbg(FLOODING_CHANNEL, "I have seen this packet before and I will drop it on the floor.");
            duplicatePacket = TRUE;
        }
    }
    if (duplicatePacket == FALSE) {
        packetCache[lastUpdatedPacketCacheSlot] = myPack->payload;
        lastUpdatedPacketCacheSlot += 1;
        if (lastUpdatedPacketCacheSlot > 19) {
            lastUpdatedPacketCacheSlot = 0;
        }
        dbg_clear(FLOODING_CHANNEL, "I am node %i. I am trying to forward this message to: ", TOS_NODE_ID);
        for (i=0;i<max_neighbors;i++) {
            if (neighbor[i] == 1 && i != myPack->src) {
                dbg_clear(FLOODING_CHANNEL, "%i,", i+1);
                makePack(&sendPackage, TOS_NODE_ID, i+1 , 0, PROTOCOL_FLOODING, 0, myPack->payload, PACKET_MAX_PAYLOAD_SIZE);
                call Sender.send(sendPackage, i+1 );
            }
        }
        dbg_clear(FLOODING_CHANNEL, "\n");

    }

    
}

void makePack(pack *Package, uint16_t src, uint16_t dest, uint16_t TTL, uint16_t protocol, uint16_t seq, uint8_t* payload, uint8_t length) {
      Package->src = src;
      Package->dest = dest;
      Package->TTL = TTL;
      Package->seq = seq;
      Package->protocol = protocol;
      memcpy(Package->payload, payload, length);
}
}

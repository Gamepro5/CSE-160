module FloodingP{
    provides interface Flooding;
    uses interface Timer<TMilli> as startDelayTimer;
    uses interface SimpleSend as Sender;
}

implementation {
//prototype
void makePack(pack *Package, uint16_t src, uint16_t dest, uint16_t TTL, uint16_t protocol, uint16_t seq, uint8_t* payload, uint8_t length);

pack* packetCache[20];
int lastUpdatedPacketCacheSlot = 0;
int START_DELAY = 1; //seconds
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
    bool duplicatePacket = false;
    for (i=0;i<20;i++) {
        if (packetCache[20] == myPack) {
            //drop the packet on the floor
            dbg(FLOODING_CHANNEL, "I have seen this packet before and I will drop it on the floor.");
            duplicatePacket = true;
        }
    }
    if (duplicatePacket == false) {
        packetCache[lastUpdatedPacketCacheSlot] = myPack;
        lastUpdatedPacketCacheSlot += 1;
        if (lastUpdatedPacketCacheSlot > 19) {
            lastUpdatedPacketCacheSlot = 0;
        }

        for (i=0;i<max_neighbors;i++) {
            if (neighbor[i] == 1 && i != myPack->src) {
                makePack(&sendPackage, TOS_NODE_ID, i , 0, PROTOCOL_FLOODING, 0, myPack->src, PACKET_MAX_PAYLOAD_SIZE);
                call Sender.send(sendPackage, i );
            }
        }

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

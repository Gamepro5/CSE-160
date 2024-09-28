module NeighborDiscoveryP{
 
    provides interface NeighborDiscovery;
    uses interface Timer<TMilli> as discoveryTimer;
    uses interface SimpleSend as Sender;
}

implementation {
//prototype
void makePack(pack *Package, uint16_t src, uint16_t dest, uint16_t TTL, uint16_t protocol, uint16_t seq, uint8_t* payload, uint8_t length);

//array that stores a list of my neighbors.
int max_neighbors = 20;
int neighbors[20];
pack sendPackage;
int START_DELAY = 5; //in seconds

command void NeighborDiscovery.boot(pack* myPack){
    makePack(myPack, TOS_NODE_ID, AM_BROADCAST_ADDR , 0, PROTOCOL_NEIGHBOR_DISCOVERY, 0, "0", PACKET_MAX_PAYLOAD_SIZE);
    call Sender.send(*myPack, AM_BROADCAST_ADDR );
}

command void NeighborDiscovery.discovered(pack* myMsg){ 
    // pack sendPackage;
    dbg(GENERAL_CHANNEL, "Package Sender: %i, Package Protocol: %i, Package Payload: %s\n", myMsg->src,myMsg->protocol,myMsg->payload);
    if (myMsg->payload == "1") { //this is a reply!
        int i;
        for (i=0;i<20;i++) {
            //dbg(NEIGHBOR_CHANNEL, "i=%i\n", i);
            if (neighbors[i] == 0) {
                neighbors[i] = myMsg->src;
                break;
            }
        }
    } else {
        //reply. the number 1 in the message represents that this is a reply.
        makePack(&sendPackage, TOS_NODE_ID, myMsg->src , 0, PROTOCOL_NEIGHBOR_DISCOVERY, 0, "1", PACKET_MAX_PAYLOAD_SIZE);
        call Sender.send(sendPackage, myMsg->src );
        call discoveryTimer.startPeriodic( 100 );// THE TIMERS DO NOT WORK!!!!
        //call discoveryTimer.startOneShot(START_DELAY*1000);
    }
}

event void discoveryTimer.fired() {
    dbg(GENERAL_CHANNEL, "My node is %i, and my neighbors are: [%i, %i, %i, %i, %i, %i, %i, %i, %i, %i, %i, %i, %i, %i, %i, %i, %i, %i, %i, %i]\n", TOS_NODE_ID, neighbors[0], neighbors[1], neighbors[2], neighbors[3], neighbors[4], neighbors[5], neighbors[6], neighbors[7], neighbors[8], neighbors[9], neighbors[10], neighbors[11], neighbors[12], neighbors[13], neighbors[14], neighbors[15], neighbors[16], neighbors[17], neighbors[18], neighbors[19]);
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

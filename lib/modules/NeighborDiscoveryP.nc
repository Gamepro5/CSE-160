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
int START_DELAY = 1; //in seconds
int RE_DISCOVERY_INTERVAL = 1;

command void NeighborDiscovery.boot(){
    makePack(&sendPackage, TOS_NODE_ID, AM_BROADCAST_ADDR , 0, PROTOCOL_NEIGHBOR_DISCOVERY, 0, "0", PACKET_MAX_PAYLOAD_SIZE);
    call Sender.send(sendPackage, AM_BROADCAST_ADDR );
    call discoveryTimer.startPeriodic( START_DELAY*1000 );// THE TIMERS DO NOT WORK!!!!
    //call discoveryTimer.startOneShot(START_DELAY*1000);
}


command void NeighborDiscovery.discovered(pack* myMsg){ 
    // pack sendPackage;
    dbg(NEIGHBOR_CHANNEL, "Package Sender: %i, Package Protocol: %i, Package Payload: %s\n", myMsg->src,myMsg->protocol,myMsg->payload);
    if (myMsg->protocol == PROTOCOL_NEIGHBOR_DISCOVERY2) { //this is a reply!
        if (neighbors[myMsg->src-1] == 0) {
            neighbors[myMsg->src-1] = 1;
        }
    } else{
        //reply. the number 1 in the message represents that this is a reply.
        makePack(&sendPackage, TOS_NODE_ID, myMsg->src , 0, PROTOCOL_NEIGHBOR_DISCOVERY2, 0, "1", PACKET_MAX_PAYLOAD_SIZE);
        call Sender.send(sendPackage, myMsg->src );
        
    }
}

event void discoveryTimer.fired() {
    int i;
    dbg(NEIGHBOR_CHANNEL, "[1:%i, 2:%i, 3:%i, 4:%i, 5:%i, 6:%i, 7:%i, 8:%i, 9:%i, 10:%i, 11:%i, 12:%i, 13:%i, 14:%i, 15:%i, 16:%i, 17:%i, 18:%i, 19:%i, 20:%i]\n", neighbors[0], neighbors[1], neighbors[2], neighbors[3], neighbors[4], neighbors[5], neighbors[6], neighbors[7], neighbors[8], neighbors[9], neighbors[10], neighbors[11], neighbors[12], neighbors[13], neighbors[14], neighbors[15], neighbors[16], neighbors[17], neighbors[18], neighbors[19]);
    for (i=0;i<max_neighbors;i++) {
        neighbors[i] = 0;
    }
    makePack(&sendPackage, TOS_NODE_ID, AM_BROADCAST_ADDR , 0, PROTOCOL_NEIGHBOR_DISCOVERY, 0, "0", PACKET_MAX_PAYLOAD_SIZE);
    call Sender.send(sendPackage, AM_BROADCAST_ADDR );
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

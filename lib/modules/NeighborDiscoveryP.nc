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
int RE_DISCOVERY_INTERVAL = 1; //in seconds

command int* NeighborDiscovery.getNeighbors() {
    return neighbors;
}

command int NeighborDiscovery.getMaxNeighbors() {
    return max_neighbors;
}

command void NeighborDiscovery.boot(){

    makePack(&sendPackage, TOS_NODE_ID, AM_BROADCAST_ADDR , 0, PROTOCOL_NEIGHBOR_DISCOVERY, 0, "0", PACKET_MAX_PAYLOAD_SIZE);
    call Sender.send(sendPackage, AM_BROADCAST_ADDR );
    call discoveryTimer.startOneShot( RE_DISCOVERY_INTERVAL*1000 );
    //call discoveryTimer.startPeriodic( RE_DISCOVERY_INTERVAL*1000 );
}


command void NeighborDiscovery.discovered(pack* myMsg){
    //dbg(NEIGHBOR_CHANNEL, "Package Sender: %i, Package Protocol: %i, Package Payload: %s\n", myMsg->src,myMsg->protocol,myMsg->payload);
    if (myMsg->protocol == PROTOCOL_NEIGHBOR_DISCOVERY) {
        if (neighbors[myMsg->src-1] == 0) {
            neighbors[myMsg->src-1] = 1;
        }
    }
}

event void discoveryTimer.fired() {
    int i;
    dbg(NEIGHBOR_CHANNEL, "I am neighbors with the following nodes: ");
    for (i=0;i<max_neighbors;i++) {
        if (neighbors[i] == 1) {
            dbg_clear(NEIGHBOR_CHANNEL, "%i,", i+1);
        }
    }
    dbg_clear(NEIGHBOR_CHANNEL, "\n");
    
    /*for (i=0;i<max_neighbors;i++) {
        neighbors[i] = 0;
    }
    makePack(&sendPackage, TOS_NODE_ID, AM_BROADCAST_ADDR , 0, PROTOCOL_NEIGHBOR_DISCOVERY, 0, "0", PACKET_MAX_PAYLOAD_SIZE);
    call Sender.send(sendPackage, AM_BROADCAST_ADDR );*/
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

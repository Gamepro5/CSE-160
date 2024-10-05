module NeighborDiscoveryP{
 
    provides interface NeighborDiscovery;
    uses interface Timer<TMilli> as discoveryTimer;
    uses interface Timer<TMilli> as decayTimer;
    uses interface SimpleSend as Sender;
}

implementation {
//prototype
void makePack(pack *Package, uint16_t src, uint16_t dest, uint16_t TTL, uint16_t protocol, uint16_t seq, uint8_t* payload, uint8_t length);

//array that stores a list of my neighbors.
int max_neighbors = 20;
int max_neighbor_life = 10;
int neighbors[20];
int neighborsTTL[20];
pack sendPackage;
int RE_DISCOVERY_INTERVAL = 1; //in seconds
float DECAY_INTERVAL = 0.2; //in seconds

command int* NeighborDiscovery.getNeighbors() {
    return neighbors;
}

command int NeighborDiscovery.getMaxNeighbors() {
    return max_neighbors;
}

// On module boot (occurs when node boots)
command void NeighborDiscovery.boot(){
    // Make a packet and broadcast, sending the packet to anyone who can listen
    makePack(&sendPackage, TOS_NODE_ID, AM_BROADCAST_ADDR , 1, PROTOCOL_NEIGHBOR_DISCOVERY, 0, "0", PACKET_MAX_PAYLOAD_SIZE);
    call Sender.send(sendPackage, AM_BROADCAST_ADDR );
    
    // Initialize rediscovery
    // call discoveryTimer.startOneShot(0);
    call discoveryTimer.startPeriodic( RE_DISCOVERY_INTERVAL*1000 );
    call decayTimer.startPeriodic( DECAY_INTERVAL*1000 );
}


command void NeighborDiscovery.discovered(pack* myMsg){
    //dbg(NEIGHBOR_CHANNEL, "Package Sender: %i, Package Protocol: %i, Package Payload: %s\n", myMsg->src,myMsg->protocol,myMsg->payload);

    neighbors[myMsg->src-1] = 1;
    //dbg(NEIGHBOR_CHANNEL, "Node decay has been reset: %i, stored in index %i\n", myMsg->src,myMsg->src-1);
    neighborsTTL[myMsg->src-1] = 0;
    
    
}

event void decayTimer.fired() { //for each neighbor, increase it's decay value by 1 each decay tick. If it reaches "max_neighbor_life", forget that neighbor.
    int i;
    for (i=0;i<max_neighbors;i++) {
        if (neighbors[i] == 1) {
            neighborsTTL[i] += 1;
            if (neighborsTTL[i] >= max_neighbor_life) {
                dbg(NEIGHBOR_CHANNEL, "Node has decayed: %i\n", i+1);
                neighbors[i] = 0;
                neighborsTTL[i] = 0;
            }
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
    
    makePack(&sendPackage, TOS_NODE_ID, AM_BROADCAST_ADDR , 1, PROTOCOL_NEIGHBOR_DISCOVERY, 0, "0", PACKET_MAX_PAYLOAD_SIZE);
    call Sender.send(sendPackage, AM_BROADCAST_ADDR );
}

command void NeighborDiscovery.printNeighbors(){
    int i;
    dbg(NEIGHBOR_CHANNEL, "Neighbors: , ");
    for (i=0;i<max_neighbors;i++) {
        if(neighbors[i] == 1) dbg_clear(NEIGHBOR_CHANNEL, "%i, ", i+1);
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

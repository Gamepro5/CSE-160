module NeighborDiscoveryP{
 
    provides interface NeighborDiscovery;
    uses interface Timer<TMilli> as discoveryTimer;
    uses interface SimpleSend as Sender;

}

implementation {
    //prototype
    void makePack(pack *Package, uint16_t src, uint16_t dest, uint16_t TTL, uint16_t protocol, uint16_t seq, uint8_t* payload, uint8_t length);

    //array that stores a list of my neighbors.
    uint16_t max_neighbors = 50;
    uint16_t neighbors[50];
    pack sendPackage;
    uint16_t START_DELAY = 5; //in seconds

    // Initialized on node boot
    command void NeighborDiscovery.boot(){
        // Creates an array initializing all values to 0
        int i;
        for(i = 0; i < max_neighbors; i++){
            neighbors[i] = 0;
        }
        // Starts the discovery timer
        call discoveryTimer.startPeriodic(START_DELAY);
    }

    // Broadcasts discovery packet
    command void NeighborDiscovery.send(){
        makePack(&sendPackage, TOS_NODE_ID, AM_BROADCAST_ADDR , 0, PROTOCOL_NEIGHBOR_DISCOVERY, 0, "1", PACKET_MAX_PAYLOAD_SIZE);
        call Sender.send(sendPackage, AM_BROADCAST_ADDR);
    }

    // Executes when a packet is received from another node
    command void NeighborDiscovery.discovered(pack* myMsg){ 
        if(neighbors[myMsg->src] == 0){
            neighbors[myMsg->src]=1;
            makePack(&sendPackage, TOS_NODE_ID, myMsg->src, 0, PROTOCOL_NEIGHBOR_DISCOVERY, 0, "1", PACKET_MAX_PAYLOAD_SIZE);
            call Sender.send(sendPackage, myMsg->src);
        }
    }

    // Fires from the timer
    event void discoveryTimer.fired(){
        call NeighborDiscovery.send();
    }

    // Prints the neighbors
    command void NeighborDiscovery.printNeighbors(){
        int i;
        for(i = 0; i < max_neighbors; i++) if(neighbors[i] == 1) dbg(NEIGHBOR_CHANNEL, "Node %i has %i as a neighbor!\n", TOS_NODE_ID, i);
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

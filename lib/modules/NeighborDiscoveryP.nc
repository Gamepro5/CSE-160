module NeighborDiscoveryP{
 
 provides interface NeighborDiscovery;

 uses interface SimpleSend as Sender;
}

implementation {
//prototype
void makePack(pack *Package, uint16_t src, uint16_t dest, uint16_t TTL, uint16_t protocol, uint16_t seq, uint8_t* payload, uint8_t length);

//array that stores a list of my neighbors.
// int max_neighbors = 20;
int neighbors[20] = {0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0};
pack sendPackage;

command void NeighborDiscovery.boot(pack* myPack){
    // int i;
    // for (i=0;i<20;i++) {
    //     dbg(GENERAL_CHANNEL, "i=%i\n", i);
    //     neighbors[i]=0;
    // }
    makePack(myPack, TOS_NODE_ID, AM_BROADCAST_ADDR , 0, PROTOCOL_NEIGHBOR_DISCOVERY, 0, "0", PACKET_MAX_PAYLOAD_SIZE);
    call Sender.send(*myPack, AM_BROADCAST_ADDR );
}

command void NeighborDiscovery.discovered(pack* myMsg){ 
    // pack sendPackage;
    
    dbg(GENERAL_CHANNEL, "Package Sender: %i\n", myMsg->src);
    dbg(GENERAL_CHANNEL, "Package Protocol: %i\n", myMsg->protocol);
    dbg(GENERAL_CHANNEL, "Package Payload: %s\n", myMsg->payload);
    if (myMsg->payload == "1") { //this is a reply!
        int i;
        for (i=0;i<20;i++) {
            dbg(GENERAL_CHANNEL, "i=%i\n", i);
            if (neighbors[i] == 0) {
                neighbors[i] = myMsg->src;
                break;
            }
        }
    } else {
        //reply. the number 1 in the message represents that this is a reply.
        makePack(&sendPackage, TOS_NODE_ID, myMsg->src , 0, PROTOCOL_NEIGHBOR_DISCOVERY, 0, "1", PACKET_MAX_PAYLOAD_SIZE);
        call Sender.send(sendPackage, myMsg->src );
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

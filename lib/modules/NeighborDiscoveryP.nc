module NeighborDiscoveryP{
 provides interface NeighborDiscovery;

 uses interface SimpleSend as Sender;



}

implementation {
//prototype
void makePack(pack *Package, uint16_t src, uint16_t dest, uint16_t TTL, uint16_t protocol, uint16_t seq, uint8_t* payload, uint8_t length);

//array that stores a list of my neighbors.

command void NeighborDiscovery.boot(pack sendPackage){
    
    makePack(&sendPackage, TOS_NODE_ID, AM_BROADCAST_ADDR , 0, PROTOCOL_NEIGHBOR_DISCOVERY, 0, "ggfg", PACKET_MAX_PAYLOAD_SIZE);
    call Sender.send(sendPackage, AM_BROADCAST_ADDR );
}

command void NeighborDiscovery.discovered(pack* myMsg){  
    //this is where you store the sender in an array
    dbg(GENERAL_CHANNEL, "Package sender: %i\n", myMsg->src);
    dbg(GENERAL_CHANNEL, "Package protocol: %i\n", myMsg->protocol);
    dbg(GENERAL_CHANNEL, "Package Payload: %s\n", myMsg->payload);
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

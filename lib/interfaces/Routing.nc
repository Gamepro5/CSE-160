interface Routing
{
   command void init();
   command void floodLinkState();
   command void receivedLinkStatePacket(pack* myMsg);
   command void forward(pack* myMsg);
   command void calculateSP();
   command void printRoutingTable();
   event void updateRouteTable(void* data, uint8_t len);
}

interface Routing
{
   command void init();
   command void floodLinkState();
   command void receivedLinkStatePacket(pack* myMsg);
   command void forward(uint16_t destination, uint8_t* payload);
   command void calculateSP();
   command void printLinkState();
}

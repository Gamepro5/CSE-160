interface CommandHandler
{
   // Events
   event void ping(uint16_t destination, uint8_t *payload);
   event void printNeighbors();
   event void printRouteTable();
   event void printLinkState();
   event void printDistanceVector();
   event void setTestServer();
   event void setTestClient();
   event void setAppServer();
   event void setAppClient();
   event void flood(uint16_t destination, uint8_t* payload);
   event void send(uint16_t destination, uint8_t* payload);
   event void startLinkState();
   event void calculateSP();
   event void connectTCP(uint16_t addr, socket_port_t port);
   event void closeTCP(socket_t fd);
   event void listenTCP(socket_t fd);
   event void sendTCP(uint16_t addr, socket_port_t port, uint8_t* payload);
}

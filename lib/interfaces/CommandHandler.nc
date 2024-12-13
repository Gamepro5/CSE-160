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
   event void listenChat(socket_t fd);
   event void helloChat(uint16_t address, uint8_t port, uint8_t* username);
   event void msgChat(uint8_t message);
   event void whisperChat(uint8_t message, uint8_t* username);
   event void listChat();
}

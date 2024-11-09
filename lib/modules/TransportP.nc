module TransportP
{
    provides interface Transport;
    uses interface Routing;

    uses interface Timer<TMilli> as waitTimer;
    uses interface SimpleSend as Sender;
}

implementation
{
   uint16_t sequenceNum;
   socket_store_t socket[MAX_NUM_OF_SOCKETS];
   
   
   event void waitTimer.fired()
   {

   }
   
   command socket_t Transport.socket()
   {

   }

   command error_t Transport.bind(socket_t fd, socket_addr_t *addr)
   {

   }

   command socket_t Transport.accept(socket_t fd)
   {

   }
   
   command uint16_t Transport.write(socket_t fd, uint8_t *buff, uint16_t bufflen)
   {
    
   }

   command error_t Transport.receive(pack* package)
   { //dispach the packet to the right TCP sub protocol
    
    /*
    nx_uint8_t srcPort;
	nx_uint8_t destPort;
	nx_uint16_t seq;
	nx_uint8_t TTL;
	nx_uint8_t length;
	nx_uint8_t flags;
	nx_uint8_t payload[ROUTING_MAX_PAYLOAD_SIZE];
    */
        transportHeader* header = (transportHeader*)&(package->payload);


   }

   command uint16_t Transport.read(socket_t fd, uint8_t *buff, uint16_t bufflen)
   {
    
   }

   command error_t Transport.connect(socket_t fd, socket_addr_t * addr)
   {
    
   }

   command error_t Transport.close(socket_t fd)
   {
    
   }

   command error_t Transport.release(socket_t fd)
   {
    
   }

   command error_t Transport.listen(socket_t fd)
   {
    
   }
}
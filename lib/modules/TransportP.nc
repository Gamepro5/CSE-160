module TransportP
{
    provides interface Transport;
    uses interface Routing;

    uses interface Timer<TMilli> as connectTimer;
    uses interface Timer<TMilli> as activeTimer;
    uses interface SimpleSend as Sender;
}

implementation
{
    error_t verify(socket_t fd, uint16_t addr, socket_port_t port);
    
    uint16_t sequenceNum = 0;
    socket_store_t socket[MAX_NUM_OF_SOCKETS];
    socket_t connectCache[MAX_NUM_OF_SOCKETS];
    uint8_t connectReadPointer = 0;
    uint8_t connectWritePointer = 0;
    Route routeTable[MAX_ROUTING];
    pack sendPackage;
   
    // Event triggers when routing table is updated in Routing module
    event void Routing.updateRouteTable(void* data, uint8_t len)
    {
        memcpy(&routeTable, data, len);
    }

    event void connectTimer.fired()
    {
        dbg(TRANSPORT_CHANNEL, "Connect timer expired for %i: ", socket[connectCache[connectReadPointer]].dest.addr);
        if(socket[connectCache[connectReadPointer]].state == SYN_SENT 
        || socket[connectCache[connectReadPointer]].state == SYN_RCVD)
        {
            dbg_clear(TRANSPORT_CHANNEL, "Reply not received, terminating connection..\n");
            socket[connectCache[connectReadPointer]].state = CLOSED;
        }
        else dbg_clear(TRANSPORT_CHANNEL, "Reply received, ignoring..\n");
        if(++connectReadPointer >= MAX_NUM_OF_SOCKETS) connectReadPointer = 0;
    }

    event void activeTimer.fired()
    {

    }
   
    command socket_t Transport.socket()
    {
        socket_t i;
        for(i = 0; i < MAX_NUM_OF_SOCKETS; i++)
        {
            if(socket[i].state == CLOSED) return i;
        }
        return INFINITY;
    }

    command error_t Transport.bind(socket_t fd, socket_addr_t *addr)
    {

    }

    command socket_t Transport.accept(socket_t fd)
    {
        if(socket[fd].state != LISTEN) return NULL;
        else return fd;
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
        transportheader* header = (transportheader*)&(package->payload);
        
        if(package->dest == TOS_NODE_ID)
        {
            // do stuff upon receiving it

            // If SYN flag 
            if(header->flags == 0b10000000)
            {
                socket_addr_t addr;
                uint8_t flags = 0b11000000;
                socket_t sock = call Transport.accept(header->destPort);
                
                dbg(TRANSPORT_CHANNEL, "Received SYN from %i:%i\n", package->src, header->srcPort);
                if(sock == NULL) return FAIL;

                addr.addr = package->src;
                addr.port = header->srcPort;
                
                socket[sock].state = SYN_RCVD;
                socket[sock].src = header->destPort;
                socket[sock].dest = addr;

                makeTransportPack(&sendPackage, TOS_NODE_ID, socket[sock].dest.addr, PROTOCOL_TCP, sock, socket[sock].dest.port, MAX_TTL, sequenceNum++, flags, 0, 0, "");
                call Sender.send(sendPackage, routeTable[sendPackage.dest-1].to);
                
                connectCache[connectWritePointer++] = sock;
                call connectTimer.startOneShot(10000);
                return SUCCESS;
            }
            // If SYN ACK flag
            else if(header->flags == 0b11000000)
            {
                socket_addr_t addr;
                uint8_t flags = 0b01000000;
                socket_t sock = header->destPort;
                
                dbg(TRANSPORT_CHANNEL, "Received SYN ACK from %i:%i\n", package->src, header->srcPort);
                // check if ACK is valid
                if(socket[sock].state != SYN_SENT) return FAIL;

                addr.addr = package->src;
                addr.port = header->srcPort;
                
                socket[sock].state = ESTABLISHED;
                socket[sock].src = header->destPort;
                socket[sock].dest = addr;

                makeTransportPack(&sendPackage, TOS_NODE_ID, socket[sock].dest.addr, PROTOCOL_TCP, sock, socket[sock].dest.port, MAX_TTL, sequenceNum++, flags, 0, 0, "");
                call Sender.send(sendPackage, routeTable[sendPackage.dest-1].to);

                return SUCCESS;
            }
            // If ACK flags
            else if(header->flags == 0b01000000)
            {
                socket_t sock = header->destPort;

                dbg(TRANSPORT_CHANNEL, "Received ACK from %i:%i\n", package->src, header->srcPort);
                // check if ACK is valid
                if(socket[header->destPort].state != SYN_RCVD) return FAIL;
                
                socket[sock].state = ESTABLISHED;

                return SUCCESS;
            }

            // If FIN flag 
            if(header->flags == 0b00100000)
            {
                socket_t sock = header->destPort;
                uint8_t flags = 0b01100000; // ACK FIN flags
                
                // if(!verify(header->destPort, package->src, header->destPort)) return FAIL;

                dbg(TRANSPORT_CHANNEL, "Received FIN from %i:%i\n", package->src, header->srcPort);

                makeTransportPack(&sendPackage, TOS_NODE_ID, socket[sock].dest.addr, PROTOCOL_TCP, sock, socket[sock].dest.port, MAX_TTL, sequenceNum++, flags, 0, 0, "");
                call Sender.send(sendPackage, routeTable[sendPackage.dest-1].to);

                // dbg(TRANSPORT_CHANNEL, "SOCKET %i IS %s\n", sock, (socket[sock].state == ESTABLISHED) ? "ESTABLISHED" : "NOT ESTABLISHED");
                if(socket[sock].state == ESTABLISHED)
                {
                    flags = 0b00100000; // FIN flag
                    // sends fin....
                    makeTransportPack(&sendPackage, TOS_NODE_ID, socket[sock].dest.addr, PROTOCOL_TCP, sock, socket[sock].dest.port, MAX_TTL, sequenceNum++, flags, 0, 0, "");
                    call Sender.send(sendPackage, routeTable[sendPackage.dest-1].to);
                }
                return SUCCESS;
            }
            // If ACK FIN flag
            else if(header->flags == 0b01100000)
            {
                // if(!verify(header->destPort, package->src, header->destPort)) return FAIL;
                dbg(TRANSPORT_CHANNEL, "Received ACK FIN from %i:%i\n", package->src, header->srcPort);

                call Transport.release(header->destPort);
                return SUCCESS;
            }

            // Other logic where flags don't apply
            // It will need to look at the packet for the dest port and perform a read operation
            return SUCCESS;
        }
        // or pass it along
        dbg(TRANSPORT_CHANNEL, "Received PACK from %i:%i, passing along...\n", package->src, header->srcPort);
        call Sender.send(*package, routeTable[package->dest-1].to);
        return SUCCESS;
    }

    command uint16_t Transport.read(socket_t fd, uint8_t *buff, uint16_t bufflen)
    {
        
    }

    command error_t Transport.connect(socket_t fd, socket_addr_t *addr)
    {
        uint8_t flags = 0b00000000;
        if(fd == INFINITY) return FAIL;

        socket[fd].state = SYN_SENT;
        socket[fd].src = fd;
        socket[fd].dest = *addr;

        dbg(TRANSPORT_CHANNEL, "Using socket %i for %i:%i\n", fd, addr->addr, addr->port);

        flags = 0b10000000; // first bit is a 1, rest is zero (first bit implies SYN flag)

        makeTransportPack(&sendPackage, TOS_NODE_ID, socket[fd].dest.addr, PROTOCOL_TCP, fd, addr->port, MAX_TTL, sequenceNum++, flags, 0, 0, "");
        dbg(TRANSPORT_CHANNEL, "Sending packet to %i\n", routeTable[sendPackage.dest-1].to);
        call Sender.send(sendPackage, routeTable[sendPackage.dest-1].to);

        connectCache[connectWritePointer++] = fd;
        call connectTimer.startOneShot(10000);
        return SUCCESS;
    }

    command error_t Transport.close(socket_t fd)
    {
        uint8_t flags = 0b00100000;
        
        // Active close
        if(call Transport.release(fd) == SUCCESS)
        {
            flags = 0b00100000;
            makeTransportPack(&sendPackage, TOS_NODE_ID, socket[fd].dest.addr, PROTOCOL_TCP, fd, socket[fd].dest.port, MAX_TTL, sequenceNum++, flags, 0, 0, "");
            call Sender.send(sendPackage, routeTable[sendPackage.dest-1].to);
            return SUCCESS;
        }
        else return FAIL;
    }

    command error_t Transport.release(socket_t fd)
    {
        if(socket[fd].state == CLOSED) return FAIL;
        
        socket[fd].state = CLOSED;
        
        dbg(TRANSPORT_CHANNEL, "Closed port %i\n", fd);
        return SUCCESS;
    }

    command error_t Transport.listen(socket_t fd)
    {
        socket_addr_t addr;
        if(socket[fd].state != CLOSED) return FAIL;

        socket[fd].state = LISTEN;
        socket[fd].src = fd;
        addr.port = INFINITY;
        addr.addr = INFINITY;
        socket[fd].dest = addr;

        return SUCCESS;
    }

    bool verify(socket_t fd, uint16_t addr, socket_port_t port)
    {
        if(socket[fd].dest.addr == addr && socket[fd].dest.port == port) return TRUE;
        else return FALSE;
    }
}
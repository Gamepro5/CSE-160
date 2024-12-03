module TransportP
{
    provides interface Transport;
    uses interface Routing;

    uses interface Timer<TMilli> as connectTimer;
    uses interface Timer<TMilli> as activeTimer;
    uses interface Timer<TMilli> as sendTimer;
    uses interface SimpleSend as Sender;

    // uses interface Queue<message_tcp_t*>;
    // uses interface Queue<message_tcp_t> as DataQueue;
    // uses interface Pool<message_tcp_t>;
    uses interface Queue<socket_t> as SendQueue;
    uses interface Queue<socket_t> as TimerQueue;
    uses interface Queue<pack> as ReceiveQueue;
}

#define SLIDING_WINDOW_SIZE 4

implementation
{
    task void sendData();
    task void receiveData();
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
        else
        {
            dbg_clear(TRANSPORT_CHANNEL, "Reply received, ignoring..\n");

            // SEND BUFFER HERE !!!!
            // call Transport.sendBuff(); ? or something like that haven't figured out exactly how it's 100% going to work/operate
        }
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
    
    // *buff = starting point of buffer data (from full size payload)
    // bufflen = length/distance from starting point
    command uint16_t Transport.write(socket_t fd, uint8_t *buff, uint16_t bufflen)
    {
        uint16_t totalData = 0;
        uint8_t i;

        // For each variable in the 
        for(i = 0; (i < bufflen && i < SOCKET_BUFFER_SIZE); i++)
        {
            memcpy(socket[fd].sendBuff + i, buff + i, sizeof(uint8_t));
            totalData++;
        }

        dbg(TRANSPORT_CHANNEL, "i=%i, buffer=\"%s\"\n", i, socket[fd].sendBuff);

        return totalData;
    }

    // Executed by dispatcher in Node.nc
    // Handles a TCP packet when received by the radio
    command error_t Transport.receive(pack* package)
    { 
        transportheader* header = (transportheader*)&(package->payload);
        
        // If the packet is destined for this node
        if(package->dest == TOS_NODE_ID)
        {
            // If SYN flag 
            if(header->flags == 0b10000000)
            {
                socket_addr_t addr;
                uint8_t flags = 0b11000000;
                // Gets the socket that corresponds to the port
                // ONLY if the socket is listening, otherwise NULL
                socket_t fd = call Transport.accept(header->destPort);
                
                dbg(TRANSPORT_CHANNEL, "Received SYN from %i:%i\n", package->src, header->srcPort);

                // If the socket is NULL (not listening), abort
                if(fd == NULL) return FAIL;

                // Assign address properties for socket destination
                addr.addr = package->src;
                addr.port = header->srcPort;
                
                // Update values to local socket
                socket[fd].state = SYN_RCVD;
                socket[fd].src = header->destPort;
                socket[fd].dest = addr;

                // Create a SYN ACK packet and send
                makeTransportPack(&sendPackage, TOS_NODE_ID, socket[fd].dest.addr, PROTOCOL_TCP, fd, socket[fd].dest.port, MAX_TTL, sequenceNum, flags, SLIDING_WINDOW_SIZE, 0, "");
                call Sender.send(sendPackage, routeTable[sendPackage.dest-1].to);
                
                // Store socket fd in cache, and start timer listening for an ACK
                connectCache[connectWritePointer++] = fd;
                call connectTimer.startOneShot(10000);

                return SUCCESS;
            }
            // If SYN ACK flag
            else if(header->flags == 0b11000000)
            {
                socket_addr_t addr;
                uint8_t flags = 0b01000000;
                socket_t fd = header->destPort;
                
                dbg(TRANSPORT_CHANNEL, "Received SYN ACK from %i:%i\n", package->src, header->srcPort);
                
                // Checks if ACK is for valid port, aborts if not valid
                if(socket[fd].state != SYN_SENT) return FAIL;

                // Assign address properties for socket destination
                addr.addr = package->src;
                addr.port = header->srcPort;
                
                // Update values to local socket
                socket[fd].state = ESTABLISHED;
                socket[fd].src = header->destPort;
                socket[fd].dest = addr;
                socket[fd].effectiveWindow = header->ack;

                // Create an ACK packet and send
                makeTransportPack(&sendPackage, TOS_NODE_ID, socket[fd].dest.addr, PROTOCOL_TCP, fd, socket[fd].dest.port, MAX_TTL, sequenceNum, flags, SLIDING_WINDOW_SIZE, 0, "");
                call Sender.send(sendPackage, routeTable[sendPackage.dest-1].to);

                // THIS IS IF WE WANT TO SEND AFTER INITIALIZING CONNECTION, NOT USING FOR THIS PROJECT
                // 
                // Perform WRITE OPERATION HERE !!!!
                // call Transport.write();

                // Define default socket values
                socket[fd].lastWritten = 0;
                socket[fd].lastAck = INFINITY;
                socket[fd].lastSent = 0;
                socket[fd].lastRead = INFINITY;
                socket[fd].lastRcvd = INFINITY;
                socket[fd].nextExpected = 0;

                return SUCCESS;
            }
            // If ACK flags
            else if(header->flags == 0b01000000)
            {
                socket_t fd = header->destPort;

                dbg(TRANSPORT_CHANNEL, "Received ACK from %i:%i\n", package->src, header->srcPort);
                
                // check if ACK is valid
                if(socket[header->destPort].state != SYN_RCVD) return FAIL;
                
                // Update values to local socket
                socket[fd].state = ESTABLISHED;
                socket[fd].lastWritten = 0;
                socket[fd].lastAck = INFINITY;
                socket[fd].lastSent = 0;
                socket[fd].lastRead = INFINITY;
                socket[fd].lastRcvd = INFINITY;
                socket[fd].nextExpected = 0;

                return SUCCESS;
            }

            // If FIN flag 
            if(header->flags == 0b00100000)
            {
                socket_t fd = header->destPort;
                uint8_t flags = 0b01100000; // ACK FIN flags
                
                // Verifies if the packet's address and port for the socket is valid
                if(!verify(header->destPort, package->src, header->destPort)) return FAIL;

                dbg(TRANSPORT_CHANNEL, "Received FIN from %i:%i\n", package->src, header->srcPort);

                // Creates and sends an ACK FIN packet
                makeTransportPack(&sendPackage, TOS_NODE_ID, socket[fd].dest.addr, PROTOCOL_TCP, fd, socket[fd].dest.port, MAX_TTL, sequenceNum++, flags, SLIDING_WINDOW_SIZE, 0, "");
                call Sender.send(sendPackage, routeTable[sendPackage.dest-1].to);

                // If the socket is ESTABLISHED
                if(socket[fd].state == ESTABLISHED)
                {
                    flags = 0b00100000; // FIN flag
                    
                    // Prints data received from the TCP connection (if any)
                    dbg(TRANSPORT_CHANNEL, "Data received from connection %i:%i; \"%s\"\n", socket[fd].dest.addr, socket[fd].dest.port, socket[fd].rcvdBuff);
                    
                    // Creates and sends a FIN packet
                    makeTransportPack(&sendPackage, TOS_NODE_ID, socket[fd].dest.addr, PROTOCOL_TCP, fd, socket[fd].dest.port, MAX_TTL, sequenceNum++, flags, SLIDING_WINDOW_SIZE, 0, "");
                    call Sender.send(sendPackage, routeTable[sendPackage.dest-1].to);
                }
                return SUCCESS;
            }
            // If ACK FIN flag
            else if(header->flags == 0b01100000)
            {
                if(!verify(header->destPort, package->src, header->destPort)) return FAIL;
                dbg(TRANSPORT_CHANNEL, "Received ACK FIN from %i:%i\n", package->src, header->srcPort);

                // Releases the socket
                call Transport.release(header->destPort);
                
                return SUCCESS;
            }
            // If dest socket in packet is ESTABLISHED
            else if(socket[header->destPort].state == ESTABLISHED)
            {
                // IF DATA flag (sent from sender to receiver)
                if(header->flags == 0b00010000)
                {
                    socket_t fd = header->destPort;
                    uint8_t flags = 0b01010000;
                    uint8_t* readPtr = &socket[fd].rcvdBuff;
                    
                    // PERFORM READ OPERATION HERE !!!!
                    // call Transport.read();
                    
                    // If the data segment received is the next expected
                    if(socket[fd].nextExpected == header->seq)
                    {
                        // Put the packet in the receive queue and
                        // Post the receiveData task
                        call ReceiveQueue.enqueue(*package);
                        post receiveData();
                        return SUCCESS;
                    }
                }
                // If DATA ACK (sent from receiver to sender)
                else if(header->flags == 0b01010000)
                {
                    socket_t fd = header->destPort;

                    // If the next ack is received
                    if(socket[fd].lastAck + 1 == header->ack
                    || (socket[fd].lastAck == 255 && header->ack == 0))
                    {
                        // Update the last ACK received in the socket
                        // Which pushes the sliding window
                        socket[fd].lastAck = header->ack;
                        dbg(TRANSPORT_CHANNEL, "Received acknowledgement of segment %i, sliding window to %i\n", socket[fd].lastAck, (uint8_t)(socket[fd].lastAck + 1));
                    }
                    // Otherwise, don't move the sliding window
                    else dbg(TRANSPORT_CHANNEL, "Received acknowledgement of segment %i, window still starts at %i\n", socket[fd].lastAck, (socket[fd].lastAck == 255) ? 0 : socket[fd].lastAck);
                    
                    return SUCCESS;
                }
                return SUCCESS;
            }
        }
        // Other logic where flags don't apply
        // It will need to look at the packet for the dest port and perform a read operation
        // Pass along the packet IF not for self and hasn't reached destination
        dbg(TRANSPORT_CHANNEL, "Received PACK from %i:%i, passing along...\n", package->src, header->srcPort);
        call Sender.send(*package, routeTable[package->dest-1].to);

        return SUCCESS;
    }


    // Unused, will implement for project 4 if needed (which it probably will be needed)
    command uint16_t Transport.read(socket_t fd, uint8_t *buff, uint16_t bufflen)
    {
        // uint8_t i;
        // uint8_t windowStart = socket[fd].lastAck + 1;
        // uint8_t* readPtr = &socket[fd].rcvdBuff;
        
        // Sends data fragments from buffer from the window
        // for(i = windowStart; i < (windowStart + SLIDING_WINDOW_SIZE); i++)

        // for(i = 0; i < SOCKET_BUFFER_SIZE; i++)
        // {
        //     if(socket[fd].rcvdBuff[i] != 0b00000000) totalData++;
        // }

        // memcpy(readPtr + );

        // return totalData;
    }

    // Command called when initializing a connection with another node
    command error_t Transport.connect(socket_t fd, socket_addr_t *addr)
    {
        uint8_t flags = 0b10000000; // first bit is a 1, rest is zero (first bit implies SYN flag)
        
        // If the socket is INFINITY (not valid), abort
        if(fd == INFINITY) return FAIL;

        // Update local socket values
        socket[fd].state = SYN_SENT;
        socket[fd].src = fd;
        socket[fd].dest = *addr;

        dbg(TRANSPORT_CHANNEL, "Using socket %i for %i:%i\n", fd, addr->addr, addr->port);
        dbg(TRANSPORT_CHANNEL, "Sending packet to %i\n", routeTable[sendPackage.dest-1].to);
        
        // Creates a SYN packet and forwards to destination
        makeTransportPack(&sendPackage, TOS_NODE_ID, socket[fd].dest.addr, PROTOCOL_TCP, fd, addr->port, MAX_TTL, sequenceNum++, flags, SLIDING_WINDOW_SIZE, 0, "");
        call Sender.send(sendPackage, routeTable[sendPackage.dest-1].to);

        // Adds socket to connect cache and starts the connect timer
        connectCache[connectWritePointer++] = fd;
        call connectTimer.startOneShot(10000);
        return SUCCESS;
    }

    // Command called when closing a connection with another node
    command error_t Transport.close(socket_t fd)
    {
        uint8_t flags = 0b00100000; // FIN flag
        
        // Active close
        if(call Transport.release(fd) == SUCCESS)
        {
            // Creates and sends a FIN packet and forwards to destination
            makeTransportPack(&sendPackage, TOS_NODE_ID, socket[fd].dest.addr, PROTOCOL_TCP, fd, socket[fd].dest.port, MAX_TTL, sequenceNum++, flags, 0, 0, "");
            call Sender.send(sendPackage, routeTable[sendPackage.dest-1].to);

            return SUCCESS;
        }
        else return FAIL;
    }

    // Command used for officially closing the local socket
    command error_t Transport.release(socket_t fd)
    {
        // If socket is already closed, abort
        if(socket[fd].state == CLOSED) return FAIL;
        
        // Update the local socket
        socket[fd].state = CLOSED;
        
        dbg(TRANSPORT_CHANNEL, "Closed port %i\n", fd);
        return SUCCESS;
    }

    // Command used for opening a socket to listen for incoming connections
    command error_t Transport.listen(socket_t fd)
    {
        socket_addr_t addr;

        // If the socket is not closed, abort
        if(socket[fd].state != CLOSED) return FAIL;

        // Update local socket values
        socket[fd].state = LISTEN;
        socket[fd].src = fd;
        addr.port = INFINITY;
        addr.addr = INFINITY;
        socket[fd].dest = addr;

        return SUCCESS;
    }

    // Command used to retrieve the correct socket based on the 
    command socket_t Transport.retrieve(socket_addr_t *addr)
    {
        socket_t i;
        for(i = 0; i < MAX_NUM_OF_SOCKETS; i++)
        {
            if(socket[i].dest.addr == addr->addr
            && socket[i].dest.port == addr->port) return i;
        }
        return ROOT_SOCKET_ADDR;
    }

    command error_t Transport.send(uint16_t addr, socket_port_t port, uint8_t* payload)
    {
        socket_addr_t dest;
        socket_t fd;
        
        dest.addr = addr;
        dest.port = port;
        fd = call Transport.retrieve(&dest);

        if(fd == ROOT_SOCKET_ADDR || socket[fd].state != ESTABLISHED)
        {
            dbg(TRANSPORT_CHANNEL, "ERROR: Not connected to %i:%i\n", addr, port);
            return FAIL;
        }
        dbg(TRANSPORT_CHANNEL, "Current payload to send: \"%s\"\n", payload);
        
        socket[fd].lastWritten = call Transport.write(fd, payload, strlen(payload));
        socket[fd].lastAck = INFINITY;
        socket[fd].lastSent = 0;

        call SendQueue.enqueue(fd);
        post sendData();
        dbg(TRANSPORT_CHANNEL, "TASK POSTED: Send data to %i:%i\n", addr, port);
        return SUCCESS;
    }

    event void sendTimer.fired()
    {
        socket_t fd = call TimerQueue.dequeue();
        dbg(TRANSPORT_CHANNEL, "Send timer fired: ");
        // Check if socket is still active
        if(socket[fd].state != ESTABLISHED) 
        {
            dbg_clear(TRANSPORT_CHANNEL, "Connection no longer open!\n");
            return;
        }
        dbg_clear(TRANSPORT_CHANNEL, "Connection still open! Last ack received is %i\n", socket[fd].lastAck);

        if(socket[fd].lastAck < 200
        && (socket[fd].lastAck+1)*TRANSPORT_MAX_PAYLOAD_SIZE >= SOCKET_BUFFER_SIZE-1) return;
        call SendQueue.enqueue(fd);
        post sendData();
    }

    task void sendData()
    {
        if(! call SendQueue.empty())
        {
            socket_t fd = call SendQueue.dequeue();
            uint8_t flags = 0b00010000;

            uint8_t i;
            uint8_t windowStart = socket[fd].lastAck;
            uint8_t lastWritten = 
                (socket[fd].lastWritten % TRANSPORT_MAX_PAYLOAD_SIZE != 0) ? 
                socket[fd].lastWritten/TRANSPORT_MAX_PAYLOAD_SIZE
                :
                socket[fd].lastWritten/TRANSPORT_MAX_PAYLOAD_SIZE + 1;
            uint8_t* writePtr = &socket[fd].sendBuff;
            if(windowStart == INFINITY) windowStart = 0;
            else windowStart++;
            dbg(TRANSPORT_CHANNEL, "Last written is %i from %i\n", lastWritten, socket[fd].lastWritten);
            // Sends data fragments from buffer from the window
            for(i = windowStart; i < (windowStart + SLIDING_WINDOW_SIZE) && i < SOCKET_BUFFER_SIZE && i <= lastWritten; i++)
            {
                uint8_t payload[TRANSPORT_MAX_PAYLOAD_SIZE];
                uint8_t* nullterm = "\0";
                // Extracts data from socket and puts in payload
                memcpy(payload, writePtr + i*TRANSPORT_MAX_PAYLOAD_SIZE, TRANSPORT_MAX_PAYLOAD_SIZE);
                memcpy(payload + TRANSPORT_MAX_PAYLOAD_SIZE, nullterm, 1);

                makeTransportPack(&sendPackage, TOS_NODE_ID, socket[fd].dest.addr, PROTOCOL_TCP, fd, socket[fd].dest.port, MAX_TTL, i, flags, SLIDING_WINDOW_SIZE, 0, payload);
                call Sender.send(sendPackage, routeTable[sendPackage.dest-1].to);
                dbg(TRANSPORT_CHANNEL, "windowPos=%i, fd=%i, msg=\"%s\"\n", i, fd, payload);

                socket[fd].lastSent = i*TRANSPORT_MAX_PAYLOAD_SIZE;
            }
            
            // Fires send timer
            call sendTimer.startOneShot(1667);
            call TimerQueue.enqueue(fd);
            
            post sendData();
            return;
        }
    }

    task void receiveData()
    {
        if(! call ReceiveQueue.empty())
        {
            pack packdata = call ReceiveQueue.dequeue();
            pack* package = &packdata;
            transportheader* header = (transportheader*)&(package->payload);
            socket_t fd = header->destPort;
            uint8_t flags = 0b01010000;
            uint8_t* readPtr = &socket[fd].rcvdBuff;
            

            dbg(TRANSPORT_CHANNEL, "I received a data packet from %i:%i, seq=%i, \"%s\"\n", package->src, header->srcPort, header->seq, header->payload);

            memcpy(readPtr + header->seq*TRANSPORT_MAX_PAYLOAD_SIZE, header->payload, TRANSPORT_MAX_PAYLOAD_SIZE);
            
            dbg(TRANSPORT_CHANNEL, "Current buffer: \"%s\"\n", readPtr);

            socket[fd].nextExpected++;
            dbg(TRANSPORT_CHANNEL, "Next Expected segment is now %i\n", socket[fd].nextExpected);

            if(socket[fd].lastRead < header->seq*TRANSPORT_MAX_PAYLOAD_SIZE) socket[fd].lastRead = header->seq*TRANSPORT_MAX_PAYLOAD_SIZE;
            if(socket[fd].lastRcvd < header->seq*TRANSPORT_MAX_PAYLOAD_SIZE) socket[fd].lastRcvd = header->seq*TRANSPORT_MAX_PAYLOAD_SIZE;

            makeTransportPack(&sendPackage, TOS_NODE_ID, socket[fd].dest.addr, PROTOCOL_TCP, fd, socket[fd].dest.port, MAX_TTL, sequenceNum++, flags, SLIDING_WINDOW_SIZE, header->seq, "");
            call Sender.send(sendPackage, routeTable[sendPackage.dest-1].to);

            post receiveData();
        }
    }

    bool verify(socket_t fd, uint16_t addr, socket_port_t port)
    {
        if(socket[fd].dest.addr == addr && socket[fd].dest.port == port) return TRUE;
        else return FALSE;
    }
}

    // task void sendData()
    // {
    //     // If all data hasn't been sent yet
    //     if(! call Queue.empty())
    //     {
    //         message_tcp_t* msg;
    //         socket_t fd;
    //         uint8_t* buff;
    //         message_tcp_t *raw_msg;
    //         void *payload;

    //         // Gets first in queue
    //         raw_msg = call Queue.dequeue();
    //         call Pool.put(raw_msg);

    //         // Check to see if the packet is valid.
    //         // if(!payload){
    //         //     call Pool.put(raw_msg);
    //         //     post processCommand();
    //         //     return;
    //         // }
            
    //         msg = (message_tcp_t*) raw_msg;
    //         buff = (uint8_t*) msg->message;
    //         fd = msg->fd;
            
    //         // Check if socket is still active
    //         if(socket[fd].state != ESTABLISHED) return;

    //         dbg(TRANSPORT_CHANNEL, "fd=%i, msg=\"%s\"\n", fd, buff);

    //         // Continue to send data
            

    //         // Repost the task
    //         // post sendData();
    //     }
    // }

    // task void sendData()
    // {
    //     // If all data in the sliding window hasn't been sent yet, proceed with the task
    //     // (The queue is the sliding window)
    //     if(! call DataQueue.empty())
    //     {
    //         message_tcp_t msg;
    //         socket_t fd;
    //         uint8_t payload[TRANSPORT_MAX_PAYLOAD_SIZE];
    //         uint8_t flags;

    //         // Gets first in queue
    //         msg = call DataQueue.dequeue();
            
    //         // Extracts data from queue item
    //         memcpy(payload, msg.message, TRANSPORT_MAX_PAYLOAD_SIZE);
    //         fd = msg.fd;
            
    //         // Check if socket is still active
    //         if(socket[fd].state != ESTABLISHED) return;

    //         dbg(TRANSPORT_CHANNEL, "fd=%i, msg=\"%s\"\n", fd, payload);

    //         // Send the data from queue
    //         flags = 0b00010000;
    //         makeTransportPack(&sendPackage, TOS_NODE_ID, socket[fd].dest.addr, PROTOCOL_TCP, fd, socket[fd].dest.port, MAX_TTL, sequenceNum, flags, 0, 0, msg.message);
    //         call Sender.send(sendPackage, routeTable[sendPackage.dest-1].to);

    //         // Repost the task
    //         post sendData();
    //         return;
    //     }
    //     // Refires the timer after queue has been cleared
    //     call sendTimer.startOneShot(5000);
    // }
module ChatP
{
    provides interface Chat;
    uses interface SimpleSend as Sender;
    uses interface Transport;
    
    uses interface Queue<socket_t> as ConnectQueue;
    uses interface Timer<TMilli> as connectTimer;
}

typedef nx_struct username_store_t
{
    uint8_t username[11];
}
username_store_t;

implementation
{
    socket_t connectedServer;
    
    bool activeClients[MAX_NUM_OF_SOCKETS];
    socket_t activeServer;

    username_store_t username[MAX_NUM_OF_SOCKETS];

    pack sendPackage;

    event void connectTimer.fired()
    {
        if(! call ConnectQueue.empty())
        {
            socket_t fd = call ConnectQueue.dequeue();

            if(call Transport.isEstablished(fd))
            {
                socket_addr_t dest = call Transport.getDest(fd);
                
                uint8_t* message = "hello " + username + " " + fd + "\r\n";
                
                call Transport.send(dest.addr, dest.port, message);
            }
        }
    }

    command error_t Chat.connectToServer(uint8_t* username, uint16_t address, uint8_t port)
    {
        socket_t fd = call Transport.socket();
        socket_addr_t dest;
        uint8_t* nullterm = "\0";
        
        dest.addr = address;
        dest.port = port;

        if(call Transport.connect(fd, &dest) == FAIL) return FAIL;
        
        memcpy(username[fd].username, username, 10);
        memcpy(username[fd].username + 10, nullterm, 1);

        call ConnectQueue.enqueue(fd);
        call connectTimer.startOneShot(5000);
    }

    command error_t Chat.startServer(uint8_t port)
    {
        if(call Transport.listen(port) == SUCCESS)
        {
            activeServer = (socket_t) port;
            return SUCCESS;
        }
        else return FAIL;
    }

    event void Transport.dataReceived(socket_t fd)
    {
        uint8_t message[SOCKET_BUFFER_SIZE];
        uint8_t* buffptr = call Transport.getRcvdBuff(fd);
        uint8_t i;
        uint8_t command[16];
        memcpy(message, buffptr, strlen(buffptr));

        for(i = 0; i < strlen(buffptr) && i < ; i++)
        {
            if((message[i] == '\r' && message[i+1] == '\n') || message[i] == ' ') break;
            memcpy(&command + i, &message + i, 1);
        }
        if(command == "hello")
        {
            uint8_t clientport = 0;
            
            for(i = 6; i < strlen(buffptr); i++)
            {
                if(message[i] == ' ') break;
                memcpy(username[fd].username + i-6, &message + i, 1);
            }

            i++;
            
            for(i = i; i < strlen(buffptr); i++)
            {
                if((message[i] == '\r' && message[i+1] == '\n')) break;
                clientport = clientport*10 + message[i] - 48;
            }
        }
        else if(command == "msg")
        {
            uint8_t targetMessage[111];

            for(i = 4; i < strlen(buffptr); i++)
            {
                if((message[i] == '\r' && message[i+1] == '\n')) break;
                memcpy(&targetMessage + i-beginMessage, &message + i, 1);
            }
            for(i = 0; i < MAX_NUM_OF_SOCKETS; i++)
            {
                if(activeClients[i] == TRUE 
                && strcmp(username[fd].username, targetUsername) != 0)
                {
                    call Transport.send(dest.addr, dest.port, targetMessage);
                }
                dbg("chat", "MESSAGES SENT FROM SERVER!\n");
            }
        }
        else if(command == "whisper")
        {
            uint8_t targetUsername[11];
            uint8_t targetMessage[111];
            uint8_t beginMessage;

            for(i = 8; i < strlen(buffptr); i++)
            {
                if(message[i] == ' ') break;
                memcpy(&targetUsername + i-8, &message + i, 1);
            }

            i++;
            beginMessage = i;

            for(i = i; i < strlen(buffptr); i++)
            {
                if((message[i] == '\r' && message[i+1] == '\n')) break;
                memcpy(&targetMessage + i-beginMessage, &message + i, 1);
            }
            
            for(i = 0; i < MAX_NUM_OF_SOCKETS; i++)
            {
                if(strcmp(username[fd].username, targetUsername) == 0) break;
            }
            
            if(i == MAX_NUM_OF_SOCKETS)
            {
                dbg("chat", "USERNAME NOT FOUND!\n");
            }
            else
            {
                socket_addr_t dest = call Transport.getDest(fd);
                dbg("chat", "USERNAME FOUND, MESSAGE SENT!\n");
                call Transport.send(dest.addr, dest.port, targetMessage);
            }
        }
        else if(command == "listusr")
        {
            uint8_t targetMessage[SOCKET_BUFFER_SIZE];
            uint8_t* messageHeader = "listUsrRply ";
            uint8_t* messageGap = ", ";
            uint8_t* writePtr = &targetMessage + strlen(messageHeader);
            bool firstUserAccounted = FALSE;
            socket_addr_t dest = call Transport.getDest(fd);
            
            memcpy(&targetMessage, messageHeader, strlen(messageHeader));

            for(i = 0; i < MAX_NUM_OF_SOCKETS; i++)
            {
                if(activeClients[i] == TRUE)
                {
                    if(firstUserAccounted == TRUE)
                    {
                        memcpy(writePtr, messageGap, strlen(messageGap));
                        writePtr += strlen(messageGap);
                    }
                    
                    memcpy(writePtr, username[i].username, strlen(username[i].username));
                    writePtr += strlen(username[i].username);

                    firstUserAccounted = TRUE;
                }
            }
            dbg("chat", "Sending user list to %i:%i\n", dest.addr, dest.port);
            call Transport.send(dest.addr, dest.port, targetMessage);
        }
    }
}
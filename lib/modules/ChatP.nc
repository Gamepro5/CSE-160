module ChatP
{
    provides interface Chat;
    uses interface Transport;
    
    uses interface Queue<socket_t> as ConnectQueue;
    uses interface Timer<TMilli> as connectTimer;
}

implementation
{
    socket_t connectedServer = ROOT_SOCKET_ADDR;

    bool activeClients[MAX_NUM_OF_SOCKETS];
    socket_t activeServer = ROOT_SOCKET_ADDR;

    username_store_t users[MAX_NUM_OF_SOCKETS];

    event void connectTimer.fired()
    {
        if(! call ConnectQueue.empty())
        {
            socket_t fd = call ConnectQueue.dequeue();

            if(call Transport.isEstablished(fd))
            {
                socket_addr_t dest = call Transport.getDest(fd);
                uint8_t message[SOCKET_BUFFER_SIZE];
                uint8_t* messageHeader = "hello ";
                uint8_t* messageEnd = "\r\n\0";
                uint8_t* writePtr = &message;

                memcpy(writePtr, messageHeader, strlen(messageHeader));
                writePtr += strlen(messageHeader);
                memcpy(writePtr, users[fd].username, strlen(users[fd].username));
                writePtr += strlen(users[fd].username);
                memcpy(writePtr, messageEnd, strlen(messageEnd));
                writePtr += strlen(messageEnd);
                
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
        
        memcpy(users[fd].username, username, 10);
        memcpy(users[fd].username + 10, nullterm, 1);
        users[fd].isClientSide = TRUE;
        dbg(CHAT_CHANNEL, "username %s saved for socket %i on client side\n", users[fd].username, fd);

        call ConnectQueue.enqueue(fd);
        call connectTimer.startOneShot(5000);
        return SUCCESS;
    }

    command error_t Chat.startServer(uint8_t port)
    {
        if(call Transport.listen(port) == SUCCESS)
        {
            activeServer = (socket_t) port;
            users[activeServer].isClientSide = FALSE;
            return SUCCESS;
        }
        else return FAIL;
    }

    command error_t Chat.messageServer(uint8_t* message)
    {
        uint8_t targetMessage[SOCKET_BUFFER_SIZE];
        uint8_t* messageHeader = "msg ";
        uint8_t* messageEnd = "\r\n\0";
        uint8_t* writePtr = &targetMessage + strlen(messageHeader);
        socket_addr_t dest = call Transport.getDest(connectedServer);
        
        memcpy(&targetMessage, messageHeader, strlen(messageHeader));
        memcpy(writePtr, message, strlen(message));
        writePtr += strlen(message);
        memcpy(writePtr, messageEnd, strlen(messageEnd));

        call Transport.send(dest.addr, dest.port, &targetMessage);
        return SUCCESS;
    }

    command error_t Chat.whisperUser(uint8_t* username, uint8_t* message)
    {

    }

    command error_t Chat.listUser()
    {
        uint8_t* message = "listusr\r\n\0";
        socket_addr_t dest;
        if(connectedServer == ROOT_SOCKET_ADDR) return FAIL;

        dest = call Transport.getDest(connectedServer);
        call Transport.send(dest.addr, dest.port, message);
        return SUCCESS;
    }

    event void Transport.dataReceived(socket_t fd)
    {
        uint8_t message[SOCKET_BUFFER_SIZE];
        uint8_t* buffptr = call Transport.getRcvdBuff(fd);
        uint8_t i;
        uint8_t rcvdCommand[16];
        uint8_t* readPtr = &message;
        memcpy(message, buffptr, strlen(buffptr));
        
        if(users[fd].isClientSide == TRUE)
        {
            dbg("chat", "Message received!\n");
            dbg("chat", "\"%s\"\n", message);
            return;
        }

        for(i = 0; i < strlen(buffptr); i++)
        {
            if((message[i] == '\r' && message[i+1] == '\n') || message[i] == ' ') break;
            memcpy(&rcvdCommand + i, &message + i, 1);
        }
        if(rcvdCommand == "hello")
        {
            uint8_t clientport = 0;
            
            for(i = 6; i < strlen(buffptr); i++)
            {
                if(message[i] == ' ') break;
                memcpy(users[fd].username + i-6, &message + i, 1);
            }

            i++;
            
            for(i = i; i < strlen(buffptr); i++)
            {
                if((message[i] == '\r' && message[i+1] == '\n')) break;
                clientport = clientport*10 + message[i] - 48;
            }
        }
        else if(rcvdCommand == "msg")
        {
            uint8_t targetMessage[111];
            uint8_t beginMessage;
            
            // i++;
            beginMessage = i;

            for(i = 4; i < strlen(buffptr); i++)
            {
                if((message[i] == '\r' && message[i+1] == '\n')) break;
                memcpy(&targetMessage + i-beginMessage, &message + i, 1);
            }
            for(i = 0; i < MAX_NUM_OF_SOCKETS; i++)
            {
                if(activeClients[i] == TRUE)
                {
                    socket_addr_t dest = call Transport.getDest(i);
                    call Transport.send(dest.addr, dest.port, &targetMessage);
                }
                dbg("chat", "MESSAGES SENT FROM SERVER!\n");
            }
        }
        else if(rcvdCommand == "whisper")
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
                if(strcmp(users[fd].username, targetUsername) == 0) break;
            }
            
            if(i == MAX_NUM_OF_SOCKETS)
            {
                dbg("chat", "USERNAME NOT FOUND, FAILED TO PASS WHISPER!\n");
            }
            else
            {
                socket_addr_t dest = call Transport.getDest(i);
                dbg("chat", "USERNAME FOUND, MESSAGE SENT!\n");
                call Transport.send(dest.addr, dest.port, &targetMessage);
            }
        }
        else if(rcvdCommand == "listusr")
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
                    
                    memcpy(writePtr, users[i].username, strlen(users[i].username));
                    writePtr += strlen(users[i].username);

                    firstUserAccounted = TRUE;
                }
            }
            dbg("chat", "Sending user list to %i:%i\n", dest.addr, dest.port);
            call Transport.send(dest.addr, dest.port, &targetMessage);
        }
    }
}
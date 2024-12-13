/*
* ANDES Lab - University of California, Merced
* This class provides the basic functions of a network node.
*
* @author UCM ANDES Lab
* @date   2013/09/03
*
*/
#include <Timer.h>
#include "includes/command.h"
#include "includes/packet.h"
#include "includes/CommandMsg.h"
#include "includes/sendInfo.h"
#include "includes/channels.h"
#include "includes/neighbor.h"
#include "includes/flood_cache.h"
#include "includes/Route.h"
#include "includes/LinkState.h"
#include "includes/socket.h"
#include "includes/message_tcp_t.h"
#include "includes/chat.h"


module Node
{
    uses interface Boot;

    uses interface SplitControl as AMControl;
    uses interface Receive;

    uses interface SimpleSend as Sender;
    uses interface CommandHandler;

    uses interface NeighborDiscovery;
    uses interface Flooding;
    uses interface Routing;
    uses interface Transport;
    uses interface Chat;
}

implementation
{
    pack sendPackage;

    event void Boot.booted()
    {
        call AMControl.start();
        dbg(GENERAL_CHANNEL, "Booted\n");
    }

    event void AMControl.startDone(error_t err)
    {
        if(err == SUCCESS)
        {
            dbg(GENERAL_CHANNEL, "Radio On\n");
            call NeighborDiscovery.init();
            call Routing.init();
        }
        else
        {
            //Retry until successful
            call AMControl.start();
        }
    }

    event void AMControl.stopDone(error_t err){}

    event message_t* Receive.receive(message_t* msg, void* payload, uint8_t len)
    {
        // dbg(GENERAL_CHANNEL, "Packet Received\n");
        if(len==sizeof(pack)){
            pack* myMsg=(pack*) payload;
            uint8_t message[myMsg->length];
            // if(myMsg->TTL == 0) return msg; //packet is dropped
            switch (myMsg->protocol)
            {
               case PROTOCOL_PING:
                  memcpy(&message, &(myMsg->payload), myMsg->length);
                  dbg(GENERAL_CHANNEL, "Package Payload: %s\n", message);
                  break;
               case PROTOCOL_PINGREPLY:
                  break;
               case PROTOCOL_NEIGHBOR_DISCOVERY:
                  call NeighborDiscovery.received(myMsg);
                  break;
               case PROTOCOL_FLOODING:
                  call Flooding.flood(myMsg);
                  break;
               case PROTOCOL_LINK_STATE:
                  call Routing.receivedLinkStatePacket(myMsg);
                  break;
               case PROTOCOL_ROUTING:
                  call Routing.forward(myMsg);
                  break;
               case PROTOCOL_ROUTING_REPLY:
                  call Routing.forward(myMsg);
                  break;
               case PROTOCOL_TCP:
                  call Transport.receive(myMsg);
                  break;
            }
            return msg;
         }
         dbg(GENERAL_CHANNEL, "Unknown Packet Type %d\n", len);
         return msg;
      }


    event void CommandHandler.ping(uint16_t destination, uint8_t *payload)
    {
        dbg(GENERAL_CHANNEL, "PING EVENT \n");
        makePack(&sendPackage, TOS_NODE_ID, destination, PROTOCOL_PING, payload, PACKET_MAX_PAYLOAD_SIZE);
        call Sender.send(sendPackage, destination);
    }

    event void CommandHandler.flood(uint16_t destination, uint8_t* payload)
    {
        call Flooding.startFlood(destination, payload, PROTOCOL_FLOODING);
    }

    event void CommandHandler.startLinkState()
    {
        call Routing.floodLinkState();
    }

    event void CommandHandler.send(uint16_t destination, uint8_t* payload)
    {
        makeRoutePack(&sendPackage, TOS_NODE_ID, destination, PROTOCOL_ROUTING, MAX_TTL, 0, payload);
        call Routing.forward(&sendPackage);
    }

    event void CommandHandler.printNeighbors()
    {
        call NeighborDiscovery.printNeighbors();
    }

    event void CommandHandler.printRouteTable(){}

    event void CommandHandler.printLinkState()
    {
        call Routing.printRoutingTable();
    }

    event void CommandHandler.printDistanceVector(){}

    event void CommandHandler.setTestServer(){}

    event void CommandHandler.setTestClient(){}

    event void CommandHandler.setAppServer(){}

    event void CommandHandler.setAppClient(){}

    event void CommandHandler.calculateSP()
    {
        call Routing.calculateSP();
    }

    event void NeighborDiscovery.updateNeighbors(void* data, uint8_t len, uint8_t count){}

    event void CommandHandler.connectTCP(uint16_t addr, socket_port_t port)
    {
        socket_addr_t dest;
        dest.addr = addr;
        dest.port = port;
        dbg(TRANSPORT_CHANNEL, "dest.addr=%i, dest.port=%i\n", dest.addr, dest.port);
        if(call Transport.connect(call Transport.socket(), &dest) == SUCCESS)
        {
            dbg(TRANSPORT_CHANNEL, "Connection request sent to %i:%i\n", addr, port);
        }
        else dbg(TRANSPORT_CHANNEL, "Error: No ports open!\n");
    }

    event void CommandHandler.closeTCP(socket_t fd)
    {
        if(!(call Transport.close(fd) == SUCCESS))
        {
            dbg(TRANSPORT_CHANNEL, "Error: Port %i isn't open!\n", fd);
        }
    }

    event void CommandHandler.listenTCP(socket_t fd)
    {
        if(call Transport.listen(fd) == SUCCESS)
        {
            dbg(TRANSPORT_CHANNEL, "Now listening on port %i\n", fd);
        }
        else dbg(TRANSPORT_CHANNEL, "Error: Port %i is already in use!\n", fd);
    }

    event void CommandHandler.sendTCP(uint16_t addr, socket_port_t port, uint8_t* payload)
    {
        uint8_t* payloadStr = "Our really long message indeed that can be sent now using TCP, which is hard coded because of the limitations of TestSim.py\0"; // not liking strings that are longer than a very short constraint.\0";
        dbg(TRANSPORT_CHANNEL, "Payload: %s\n", payloadStr);
        if(call Transport.send(addr, port, payloadStr) == SUCCESS)
        {
            dbg(TRANSPORT_CHANNEL, "Data sent to %i:%i\n", addr, port);
        }
        else dbg(TRANSPORT_CHANNEL, "Error: Something went wrong!\n");
    }

    event void CommandHandler.listenChat(socket_t fd)
    {
        if(call Chat.startServer(fd) == SUCCESS)
        {
            dbg(CHAT_CHANNEL, "Server started on port %i\n", fd);
        }
        else dbg(CHAT_CHANNEL, "Error: Port %i is already in use!\n", fd);
    }

    event void CommandHandler.helloChat(uint16_t address, uint8_t port, uint8_t* username)
    {
        if(call Chat.connectToServer(username, address, port) == SUCCESS)
        {
            dbg(CHAT_CHANNEL, "Attempting to connect to %i:%i as \"%s\"\n", address, port, username);
        }
        else dbg(CHAT_CHANNEL, "Error: Something went wrong when attempting to connect!\n");
    }

    event void CommandHandler.msgChat(uint8_t message)
    {
        uint8_t* output;
        if(message == 1) output = "Hello chat!\0";
        else if(message == 2) output = "Where is the beef?\0";
        else if(message == 3) output = "There is no way you did that.\0";

        if(call Chat.messageServer(output) == SUCCESS)
        {
            dbg(CHAT_CHANNEL, "Sending message \"%s\"\n", output);
        }
        else dbg(CHAT_CHANNEL, "Failed to begin sending message \"%s\"\n", message);
    }

    event void CommandHandler.whisperChat(uint8_t message, uint8_t* username)
    {
        uint8_t* output;
        if(message == 1) output = "Hello chat!\0";
        else if(message == 2) output = "Where is the beef?\0";
        else if(message == 3) output = "There is no way you did that.\0";
        
        if(call Chat.whisperUser(username, output) == SUCCESS)
        {
            dbg(CHAT_CHANNEL, "Whispering to %s: \"%s\"\n", username, message);
        }
        else dbg(CHAT_CHANNEL, "Failed to whisper to %s: \"%s\"\n", username, message);
    }

    event void CommandHandler.listChat()
    {
        if(call Chat.listUser() == SUCCESS)
        {
            dbg(CHAT_CHANNEL, "Sending list user request!\n");
        }
        else dbg(CHAT_CHANNEL, "Failed to send list user request!\n");
    }

    event void Routing.updateRouteTable(void* data, uint8_t len) {}

    event void Transport.dataReceived(socket_t fd){}
}

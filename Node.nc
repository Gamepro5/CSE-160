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
        call Routing.forward(destination, payload);
    }

    event void CommandHandler.printNeighbors()
    {
        call NeighborDiscovery.printNeighbors();
    }

    event void CommandHandler.printRouteTable(){}

    event void CommandHandler.printLinkState()
    {
        call Routing.printLinkState();
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
}

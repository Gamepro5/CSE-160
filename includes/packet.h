//Author: UCM ANDES Lab
//$Author: abeltran2 $
//$LastChangedBy: abeltran2 $

#ifndef PACKET_H
#define PACKET_H


# include "protocol.h"
#include "channels.h"

#define DISCOVERY_HEADER_LENGTH 3
#define FLOODING_HEADER_LENGTH 7

enum
{
	PACKET_HEADER_LENGTH = 6,
	PACKET_MAX_PAYLOAD_SIZE = 28 - PACKET_HEADER_LENGTH,
	
	FLOODING_MAX_PAYLOAD_SIZE = PACKET_MAX_PAYLOAD_SIZE - FLOODING_HEADER_LENGTH,

	MAX_TTL = 15
};

typedef nx_struct pack
{
	nx_uint16_t dest;
	nx_uint16_t src;
	nx_uint8_t protocol;
	nx_uint8_t length;
	nx_uint8_t payload[PACKET_MAX_PAYLOAD_SIZE];
}
pack;

typedef nx_struct discoveryheader
{
	nx_uint16_t seq;
	nx_uint8_t reply;
}
discoveryheader;

typedef nx_struct floodingheader
{
	nx_uint16_t floodsrc;
	nx_uint16_t seq;
	nx_uint8_t TTL;
	nx_uint8_t reply;
	nx_uint8_t length;
	nx_uint8_t payload[FLOODING_MAX_PAYLOAD_SIZE];
}
floodingheader;

/*
 * logPack
 * 	Sends packet information to the general channel.
 * @param:
 * 		pack *input = pack to be printed.
 */
// void logPack(pack *input)
// {
// 	dbg(GENERAL_CHANNEL, "Src: %hhu Dest: %hhu Seq: %hhu TTL: %hhu Protocol:%hhu  Payload: %s\n",
// 	input->src, input->dest, input->seq, input->TTL, input->protocol, input->payload);
// }

void makePack(pack *Package, uint16_t src, uint16_t dest, uint16_t protocol, uint8_t* payload, uint8_t length)
{
	Package->src = src;
	Package->dest = dest;
	Package->protocol = protocol;
	Package->length = length;
	memcpy(Package->payload, payload, length);
}

void makeDiscoveryPack(pack *Package, uint16_t src, uint16_t dest, uint16_t protocol, uint16_t seq, uint8_t reply)
{
	discoveryheader header;
	Package->src = src;
	Package->dest = dest;
	Package->protocol = protocol;
	header.seq = seq;
	header.reply = reply;
	Package->length = DISCOVERY_HEADER_LENGTH;
	memcpy(Package->payload, &header, Package->length);
}

void makeFloodPack(pack *Package, uint16_t src, uint16_t dest, uint16_t protocol, uint16_t floodsrc, uint16_t TTL, uint16_t seq, uint8_t reply, uint8_t* payload)
{
	floodingheader header;
	Package->src = src;
	Package->dest = dest;
	Package->protocol = protocol;
	
	header.floodsrc = floodsrc;
	header.TTL = TTL;
	header.seq = seq;
	header.reply = reply;
	header.length = FLOODING_MAX_PAYLOAD_SIZE;
	memcpy(&header.payload, payload, header.length);

	Package->length = PACKET_MAX_PAYLOAD_SIZE;
	memcpy(Package->payload, &header, Package->length);
}

enum
{
	AM_PACK=6
};

#endif

#ifndef MESSAGE_TCP_T_H
#define MESSAGE_TCP_T_H

#include "packet.h"
#include "socket.h"

typedef struct message_tcp_t
{
	socket_t fd;
    uint8_t message[TRANSPORT_MAX_PAYLOAD_SIZE];
}
message_tcp_t;

typedef struct timer_socket_t
{
	socket_t fd;
    uint8_t attempts;
}
timer_socket_t;

#endif /* MESSAGE_TCP_T_H */

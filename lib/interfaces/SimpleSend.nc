#include "../../includes/packet.h"

interface SimpleSend{ //declares all publicly accessible functions
   command error_t send(pack msg, uint16_t dest );
}

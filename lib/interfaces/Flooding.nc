interface Flooding{   
   command error_t flood(pack* myMsg);
   command void startFlood(uint16_t destination, uint8_t* payload, int protocol);
   command void addToCache(pack* Package);
}

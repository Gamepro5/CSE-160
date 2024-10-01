interface Flooding{
   command void flood(pack* myMsg);
   command void startFlood(uint16_t destination, uint8_t* payload);
   command void floodReply(pack* myMsg);
   command void floodEnd(pack* myMsg);
   command void addToCache(pack* myPack);
}

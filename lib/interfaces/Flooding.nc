interface Flooding{   
   command void flood(pack* myMsg);
   command void startFlood(uint16_t destination, uint8_t* payload);
   command void addToCache(uint16_t floodsrc, uint16_t seq);
}

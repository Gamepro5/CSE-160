interface NeighborDiscovery
{
    command void init();
    command void broadcast();
    command void received(pack* myMsg);
    command void printNeighbors();
    command void* getNeighbors(Neighbor* dest);
    event void updateNeighbors(void* data, uint8_t len);
}

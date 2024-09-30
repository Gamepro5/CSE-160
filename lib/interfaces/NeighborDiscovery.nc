interface NeighborDiscovery{

   command void discovered(pack* myMsg);
   command void boot();
   command int* getNeighbors();
   command int getMaxNeighbors();
}

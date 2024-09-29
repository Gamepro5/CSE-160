interface NeighborDiscovery{

   command void discovered(pack* myMsg);
   command void boot();
   command void printNeighbors();
   command void send();
}

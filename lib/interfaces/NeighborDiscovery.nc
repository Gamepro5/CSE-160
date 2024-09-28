interface NeighborDiscovery{

   command void discovered(pack* myMsg);
   command void boot(pack* sendPackage);
   command void printNeighbors();
}

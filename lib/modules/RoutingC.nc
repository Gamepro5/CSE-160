configuration RoutingC
{
   provides interface Routing;
}

implementation
{
    components RoutingP;
    Routing = RoutingP.Routing;

    components NeighborDiscoveryP;
    RoutingP.NeighborDiscovery -> NeighborDiscoveryP;
    
    components FloodingP;
    RoutingP.Flooding -> FloodingP;

    components new TimerMilliC() as waitTimer;
    RoutingP.waitTimer -> waitTimer;
}
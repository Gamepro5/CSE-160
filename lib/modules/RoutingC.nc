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

    components new TimerMilliC() as reCalcTimer;
    RoutingP.reCalcTimer -> reCalcTimer;

    components new SimpleSendC(AM_PACK);
    RoutingP.Sender -> SimpleSendC;
}
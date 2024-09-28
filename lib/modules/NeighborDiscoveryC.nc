configuration NeighborDiscoveryC{
   provides interface NeighborDiscovery;
}

implementation{
    components NeighborDiscoveryP;
    NeighborDiscovery = NeighborDiscoveryP.NeighborDiscovery;
    components new SimpleSendC(AM_PACK);
    NeighborDiscovery.Sender -> SimpleSendC;
}
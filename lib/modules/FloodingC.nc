configuration FloodingC{
   provides interface Flooding;
}

implementation{
    components FloodingP;
    Flooding = FloodingP.Flooding;

    components new TimerMilliC() as startDelayTimer;
    FloodingP.startDelayTimer -> startDelayTimer;

    components new SimpleSendC(AM_PACK);
    NeighborDFloodingPiscoveryP.Sender -> SimpleSendC;
}
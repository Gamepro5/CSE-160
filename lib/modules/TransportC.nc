configuration TransportC
{
   provides interface Transport;
}

implementation
{
    components TransportP;
    Transport = TransportP.Transport;

    components RoutingP;
    TransportP.Routing -> RoutingP;

    components new TimerMilliC() as waitTimer;
    TransportP.waitTimer -> waitTimer;

    components new SimpleSendC(AM_PACK);
    TransportP.Sender -> SimpleSendC;
}
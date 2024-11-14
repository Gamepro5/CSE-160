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

    components new TimerMilliC() as connectTimer;
    TransportP.connectTimer -> connectTimer;

    components new TimerMilliC() as activeTimer;
    TransportP.activeTimer -> activeTimer;

    components new SimpleSendC(AM_PACK);
    TransportP.Sender -> SimpleSendC;
}
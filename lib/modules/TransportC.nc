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

    components new TimerMilliC() as sendTimer;
    TransportP.sendTimer -> sendTimer;

    components new SimpleSendC(AM_PACK);
    TransportP.Sender -> SimpleSendC;

    // components new PoolC(message_tcp_t, 20);
    // components new QueueC(message_tcp_t*, 20);
    // components new QueueC(message_tcp_t, 20) as QueueC2;

    // TransportP.Pool -> PoolC;
    // TransportP.Queue -> QueueC; 
    // TransportP.DataQueue -> QueueC2;
    
    components new QueueC(socket_t, 10) as SendQueueC;
    TransportP.SendQueue -> SendQueueC;
    components new QueueC(socket_t, 10) as TimerQueueC;
    TransportP.TimerQueue -> TimerQueueC;
    components new QueueC(pack, 10) as ReceiveQueueC;
    TransportP.ReceiveQueue -> ReceiveQueueC;
}
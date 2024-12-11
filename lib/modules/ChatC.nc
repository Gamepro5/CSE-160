configuration
{
    provides interface Chat;
}

implementation
{
    components ChatP;
    Chat = ChatP.Chat;

    components new SimpleSendC(AM_PACK);
    ChatP.Sender -> SimpleSendC;

    components new QueueC(socket_t, 10) as ConnectQueueC;
    ChatP.ConnectQueue -> ConnectQueueC;

    components new TimerMilliC() as connectTimer;
    ChatP.connectTimer -> connectTimer;
}
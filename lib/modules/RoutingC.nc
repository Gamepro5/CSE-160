configuration RoutingC
{
   provides interface Routing;
}

implementation
{
    components RoutingP;
    Routing = RoutingP.Routing;
}
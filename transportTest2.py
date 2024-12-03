from TestSim import TestSim

def main():
    s = TestSim()
    s.runTime(10)
    s.loadTopo("example.topo")
    s.loadNoise("some_noise.txt")
    s.bootAll()
    s.addChannel(s.COMMAND_CHANNEL)
    s.addChannel(s.GENERAL_CHANNEL)
    # s.addChannel(s.NEIGHBOR_CHANNEL)
    # s.addChannel(s.FLOODING_CHANNEL)
    s.addChannel(s.ROUTING_CHANNEL)
    s.addChannel(s.TRANSPORT_CHANNEL)

    totalNodes = 9
    
    s.runTime(1)
    for i in range(totalNodes+1):
        s.neighborDMP(i)
        s.runTime(1)
    
    s.runTime(1000)
    
    for i in range(totalNodes+1):
        s.neighborDMP(i)
        s.runTime(10)
    
    for i in range(totalNodes+1):
        s.startLinkState(i)
        s.runTime(50)
    s.runTime(200)

    for i in range(totalNodes+1):
        s.calcSP(i)
        s.runTime(20)
    
    for i in range(totalNodes+1):
        s.linkStateDMP(i)
        s.runTime(1)
    
    s.listenTCP(8, 3)
    s.runTime(5)
    s.connectTCP(1, 8, 3)
    s.runTime(500)
    s.sendTCP(1, 8, 3, "Yeah no")
    s.runTime(400)
    s.closeTCP(1, 0)
    s.runTime(200)

if __name__ == '__main__':
    main()

from TestSim import TestSim

def main():
    s = TestSim();
    s.runTime(10);
    s.loadTopo("crazy.topo")
    s.loadNoise("no_noise.txt")
    s.bootAll()
    s.addChannel(s.COMMAND_CHANNEL)
    s.addChannel(s.GENERAL_CHANNEL)
    # s.addChannel(s.NEIGHBOR_CHANNEL)
    # s.addChannel(s.FLOODING_CHANNEL)
    s.addChannel(s.ROUTING_CHANNEL)
    
    s.runTime(500)
    
    totalNodes = 6
    
    for i in range(totalNodes+1):
        s.neighborDMP(i)
        s.runTime(1)
    
    for i in range(totalNodes+1):
        s.startLinkState(i)
        s.runTime(200)
    
    for i in range(totalNodes+1):
        s.calcSP(i)
        s.runTime(200)
    
    for i in range(totalNodes+1):
        s.linkStateDMP(i)
        s.runTime(1)
    
    s.send(4, 1, "Hi four!")
    s.runTime(1)
    s.send(4, 6, "Hi six!")
    s.runTime(100)
    
if __name__ == '__main__':
    main()
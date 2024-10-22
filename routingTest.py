from TestSim import TestSim

def main():
    s = TestSim()
    s.runTime(10)
    s.loadTopo("example.topo")
    s.loadNoise("no_noise.txt")
    s.bootAll()
    s.addChannel(s.COMMAND_CHANNEL)
    s.addChannel(s.GENERAL_CHANNEL)
    # s.addChannel(s.NEIGHBOR_CHANNEL)
    # s.addChannel(s.FLOODING_CHANNEL)
    s.addChannel(s.ROUTING_CHANNEL)

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
    s.runTime(100)

    for i in range(totalNodes+1):
        s.calcSP(i)
        s.runTime(20)
    
    for i in range(totalNodes+1):
        s.linkStateDMP(i)
        s.runTime(1)
    
    s.send(1, 4, "Hi four!")
    s.runTime(10)
    s.send(4, 9, "Hi nine!")
    s.runTime(10)
    s.send(2, 7, "okay!")
    s.runTime(10)
    s.send(3, 8, "wow!")
    s.runTime(10)
    s.send(1, 9, "costly!")
    s.runTime(10)
    s.runTime(500)
    
if __name__ == '__main__':
    main()

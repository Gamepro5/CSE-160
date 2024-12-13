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
    s.addChannel(s.TRANSPORT_CHANNEL)
    s.addChannel(s.CHAT_CHANNEL)

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
    
    s.listenChat(7, 3)
    s.runTime(5)
    s.helloChat(1, 7, 3, "bigmoney")
    s.runTime(500)
    s.helloChat(2, 7, 3, "smallballs")
    s.runTime(500)
    s.msgChat(1, 1)
    s.runTime(500)
    s.msgChat(2, 2)
    s.runTime(500)
    s.listChat(2)
    s.runTime(500)
    

if __name__ == '__main__':
    main()

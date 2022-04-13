#!/usr/bin/env python

from mininet.topo   import Topo
from mininet.log    import setLogLevel
from mininet.cli    import CLI
from p4app          import P4Mininet, P4Program

import os

basic_prog = P4Program('router.p4')

class InputGraphTopo(Topo):
    def add_edge (self, u, v):
        if u in self.V:
            self.V[u].append(v)
        else:
            self.V[u] = [v]

    # initialize a graph by reading the edges from the given file
    def __init__(self, filename):
        self.V = dict()         # Adjacency list: Node --> list of neighbor nodes
        self.E = set()          # Edges: set of pairs (u,v)
        f = open(filename)
        for l in f:
            u,v = l.strip().split()
            u = int(u)
            v = int(v)
            if v < u:
                u,v = v,u
            self.add_edge(u, v)
            self.add_edge(v, u)
            self.E.add((u,v))
        f.close()
        Topo.__init__(self)

    def build(self, **_opts):
        for v in self.V.keys():
            self.addSwitch('r%d' % v, program=basic_prog)
            self.addHost('h%d' % v, 
                         ip='192.168.%d.100' % v,
                         mac='00:01:01:00:00:%02x' % v)
            self.addLink('h%d' % v, 'r%d' % v,
                         intfName1='h%d-eth0' % v, 
                         intfName2='r%d-eth0' % v, port2=0)

        for u,v in self.E:
            self.addLink('r%d' % u, 'r%d' % v, 
                         intfName1='r%d-eth%d' % (u,v),
                         intfName2='r%d-eth%d' % (v,u), 
                         port1=v, port2=u)

def fill_tables(net, topo):
    r1 = net.get('r1')
    r2 = net.get('r2')
    r3 = net.get('r3')
    r4 = net.get('r4')
    r1.insertTableEntry(table_name='ingress.ipv4_lpm',
                    match_fields={'hdr.ipv4.dstAddr': ["192.168.4.0", 24]},
                    action_name='ingress.set_nhop',
                    action_params={'port': 3})
    r3.insertTableEntry(table_name='ingress.ipv4_lpm',
                    match_fields={'hdr.ipv4.dstAddr': ["192.168.4.0", 24]},
                    action_name='ingress.set_nhop',
                    action_params={'port': 4})
    r4.insertTableEntry(table_name='ingress.ipv4_lpm',
                    match_fields={'hdr.ipv4.dstAddr': ["192.168.1.0", 24]},
                    action_name='ingress.set_nhop',
                    action_params={'port': 2})
    r2.insertTableEntry(table_name='ingress.ipv4_lpm',
                    match_fields={'hdr.ipv4.dstAddr': ["192.168.1.0", 24]},
                    action_name='ingress.set_nhop',
                    action_params={'port': 1})

def run(topo_file):
    intopo = InputGraphTopo(topo_file)
    net = P4Mininet(program=basic_prog, topo=intopo)
    net.start()
    fill_tables(net, intopo)
    CLI(net)
    net.stop()

if __name__ == '__main__':
    setLogLevel( 'info' )
    os.environ["GRPC_POLL_STRATEGY"] = "poll"
    run('topo.txt')

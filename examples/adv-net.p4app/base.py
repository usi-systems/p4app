#!/usr/bin/env python

from mininet.topo import Topo
from mininet.net import Mininet
from mininet.node import Node
from mininet.log import setLogLevel, info
from mininet.cli import CLI
from mininet.link import TCLink
from mininet.util import pmonitor

from p4_mininet import P4Switch, P4Host
from time import sleep
import argparse
import os
import subprocess


_THIS_DIR = os.path.dirname(os.path.realpath(__file__))
_THRIFT_BASE_PORT = 22222

parser = argparse.ArgumentParser(description='Mininet demo')
parser.add_argument('--behavioral-exe', help='Path to behavioral executable', type=str, action="store", required=True)
parser.add_argument('--json', help='Path to JSON config file', type=str, action="store", required=True)
parser.add_argument('--cli', help='Path to BM CLI', type=str, action="store", required=True)

args = parser.parse_args()

class LinuxRouter(Node):
    def config(self, **params):
        super(LinuxRouter, self).config(**params)
        self.cmd('sysctl net.ipv4.ip_forward=1')

    def terminate(self):
        self.cmd('sysctl net.ipv4.ip_forward=0')
        super(LinuxRouter, self).terminate()

class InputGraphTopo(Topo):
    def add_edge (self, u, v):
        if u in self.V:
            self.V[u].append(v)
        else:
            self.V[u] = [v]

    # initialize a graph by reading the edges from the given file
    def __init__(self, filename, sw_path, json_path, **opts):
        self.sw_p = sw_path
        self.json_p = json_path
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
        Topo.__init__(self, **opts)

    def build(self, **_opts):
        for v in self.V.keys():
            self.addSwitch('s%d' % v,
                sw_path = self.sw_p,
                json_path = self.json_p,
                thrift_port = _THRIFT_BASE_PORT + v,
                pcap_dump = False,
                device_id = v)
            self.addHost('h%d' % v, ip=None, defaultRoute='via 10.0.%d.254' % v)
            self.addLink('h%d' % v, 's%d' % v,
                intfName1='h%d-eth0' % v, intfName2='s%d-eth0' % v)
        for u,v in self.E:
            self.addLink('s%d' % u, 's%d' % v, 
                intfName1='s%d-eth%d' % (u,v), intfName2='s%d-eth%d' % (v,u))

def configureP4Switch(**switch_args):
    class ConfiguredP4Switch(P4Switch):
        def __init__(self, *opts, **kwargs):
            global next_thrift_port
            kwargs.update(switch_args)
            kwargs['thrift_port'] = next_thrift_port
            print("PORT: ", next_thrift_port)
            next_thrift_port += 1
            P4Switch.__init__(self, *opts, **kwargs)
    return ConfiguredP4Switch

def setupHosts(topo, net):
    for v in topo.V.keys():
        h = net.get('h%d' % v)
        s = net.get('s%d' % v)
        h.cmd('ifconfig h%d-eth0 192.168.%d.100 netmask 255.255.255.0 up' % (v, v))
        h.cmd('ip route add default via 192.168.%d.1 dev h%d-eth0' % (v, v))
        s.cmd('ifconfig s%d-eth0 192.168.%d.1 netmask 255.255.255.0 up' % (v, v))
        
        # for off in ["rx", "tx", "sg"]:
        #     cmd = "/sbin/ethtool --offload h%d-eth0 %s off" % (v, off)
        #     h.cmd(cmd)
        # h.cmd("sysctl -w net.ipv6.conf.all.disable_ipv6=1")
        # h.cmd("sysctl -w net.ipv6.conf.default.disable_ipv6=1")
        # h.cmd("sysctl -w net.ipv6.conf.lo.disable_ipv6=1")
        # h.cmd("sysctl -w net.ipv4.tcp_congestion_control=reno")
        # h.cmd("iptables -I OUTPUT -p icmp --icmp-type destination-unreachable -j DROP")
        # s.cmd('sysctl net.ipv4.ip_forward=0')
        
        cmd = [args.cli, "--json", args.json, "--thrift-port", str(_THRIFT_BASE_PORT + v)]
        with open('cmd/s%d.txt' % v, "r") as f:
            # print " ".join(cmd)
            try:
                output = subprocess.check_output(cmd, stdin = f)
                # print output
            except subprocess.CalledProcessError as e:
                print("ERROR:", e, e.output)
    for u,v in topo.E:
        uu = net.get('s%d' % u)
        vv = net.get('s%d' % v)
    #     uu.cmd('ifconfig s%d-eth%d 10.%d.%d.1 netmask 255.255.255.0 up' % (u, v, u, v))
    #     vv.cmd('ifconfig s%d-eth%d 10.%d.%d.1 netmask 255.255.255.0 up' % (v, u, v, u))
        # uu.cmd('echo "1" > /proc/sys/net/ipv4/icmp_echo_ignore_all')
        # vv.cmd('echo "1" > /proc/sys/net/ipv4/icmp_echo_ignore_all')
    #     uu.cmd('ip route flush all')
    #     vv.cmd('ip route flush all')

def run(topo_file):
    topo = InputGraphTopo(topo_file, args.behavioral_exe, args.json)
    net = Mininet(topo, link = TCLink, host = P4Host, switch = P4Switch, 
            controller = None)
    net.start()
    setupHosts(topo, net)
    
    CLI(net)
    net.stop()

if __name__ == '__main__':
    setLogLevel( 'info' )
    print("BASE------>2")
    run('topo.txt')

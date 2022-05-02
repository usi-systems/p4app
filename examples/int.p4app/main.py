#!/usr/bin/env python

from mininet.topo   import Topo
from mininet.log    import setLogLevel, info
from mininet.cli    import CLI
from p4app          import P4Mininet, P4Program

import queue
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
	
	def edges_to_graph(self, n, links):
		edges = [[] for _ in range(n)]
		for a, b in links:
			edges[a - 1].append(b - 1)
			edges[b - 1].append(a - 1)

		return [sorted(x) for x in edges]
	
	def compute_routers_paths(self):
		n = len(self.V)
		neighbours = self.edges_to_graph(n, self.E)

		distances = [[float('inf') if i != j else 0 for i in range(n)] for j in range(n)]
		directions = [[[] for _ in range(n)] for _ in range(n)]

		for starting_point in range(n):
			q = queue.Queue()
			for neighbour in neighbours[starting_point]:
				q.put((starting_point, neighbour))

			while not q.empty():
				coming_from, looking_at = q.get()
				if distances[looking_at][starting_point] != float('inf'):
					continue

				distances[looking_at][starting_point] = distances[coming_from][starting_point] + 1
				directions[looking_at][starting_point] += (directions[coming_from][starting_point] + [looking_at + 1])

				for neighbour in neighbours[looking_at]:
					q.put((looking_at, neighbour))
		return directions

def dijkstra(net, topo):
	number_of_routers = len(topo.V)
	shortest_paths = topo.compute_routers_paths()
	for i in range(number_of_routers):
		for j in range(number_of_routers):
			if i == j: continue
			gateways = shortest_paths[i][j]
			add_table_entries(net, j + 1, i + 1, gateways[0])

def add_table_entries(net, s, d, gateway):
	r = net.get('r%d' % s)
	r.insertTableEntry(table_name='ingress.ipv4_lpm',
		match_fields={'hdr.ipv4.dstAddr': ['192.168.%d.0' % d, 24]},
		action_name='ingress.set_nhop',
		action_params={'port': gateway})
def insert_info(net, topo):
	for v in topo.V.keys():
		r = net.get('r%d' % v)
		r.insertTableEntry(table_name='ingress.switchid',
			match_fields={'hdr.icmp.type': 8},
			action_name='ingress.set_info',
			action_params={'_size': len(topo.V[v])-1, '_id': v})
		r.insertTableEntry(table_name='egress.snd_INT',
			match_fields={'hdr.int_info.size': 10},
			action_name='egress.snd_src',
			action_params={})
		n_index = 0
		for d in topo.V[v]:
			r.insertTableEntry(table_name='ingress.rnd_wlk',
				match_fields={'meta.ing.exit_idx': n_index},
				action_name='ingress.set_nhop',
				action_params={'port': d})
			n_index = n_index + 1

def run(topo_file):
	input_topo = InputGraphTopo(topo_file)
	net = P4Mininet(program=basic_prog, topo=input_topo)
	net.start()
	dijkstra(net, input_topo)
	insert_info(net, input_topo)

	r1 = net.get('r2')
	r1.printTableEntries()

	CLI(net)
	net.stop()

if __name__ == '__main__':
	setLogLevel( 'info' )
	os.environ["GRPC_POLL_STRATEGY"] = "poll"
	run('topo.txt')

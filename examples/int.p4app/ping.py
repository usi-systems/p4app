#! /usr/bin/env python
from scapy.all import *
from threading import Thread
from time import sleep

global app_finished
app_finished = False

def print_packet(packet):
	if(packet[0][1].dst == "192.168.1.100"):
		buf = bytes(packet[IP].payload)
		int_len = buf[4]
		old_value = 0
		for i in range(int_len):
			bindex = 5 + i * 9
			is_valid = buf[bindex]
			type = buf[bindex + 1]
			code = buf[bindex + 2]
			value = 0
			for j in range(6):
				value = value << 8
				value = value + buf[bindex+ 3 + j]
			if(i > 0):
				print("isValid:", is_valid, ", type: ", type, ", code: ", code, ", value:", (int)(value/1000))
			old_value = value
		print("---------")

def stop_sniff(a, *args):
	global app_finished
	app_finished = True
def check_input(*p):
	return app_finished
def sniff_packets():
	sniff(filter="ip", prn=print_packet, count=10000, stop_filter=check_input)

# signal.signal(signal.SIGINT,	stop_sniff)
# signal.signal(signal.SIGTERM,	stop_sniff)


new_thread = Thread(target=sniff_packets)
new_thread.start()


while(True):
	sendp(Ether(dst="00:01:01:00:00:04")/IP(dst="192.168.4.100")/ICMP()/ b"\0\0\0\0\0\0\0\0\0 alialialiali")
	sleep(1)
	if(app_finished): break

app_finished = True
sleep(1)
sys.exit(0)
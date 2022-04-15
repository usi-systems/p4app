#include <core.p4>
#include <v1model.p4>

#include "header.p4"
#include "parser.p4"

control egress(inout headers hdr, inout metadata meta, inout standard_metadata_t standard_metadata) {
	apply {
	}
}

control ingress(inout headers hdr, inout metadata meta, inout standard_metadata_t standard_metadata) {
	action doDrop() {
		mark_to_drop(standard_metadata);
	}
	action set_nhop(bit<9> port) {
		standard_metadata.egress_spec = port;
		hdr.ipv4.ttl = hdr.ipv4.ttl + 8w255;
	}
	action set_info (bit<8> _size){
		meta.ing.max_idx = _size;
		bit<32> random_t;
        random(random_t, (bit<32>)0, (bit<32>)_size);
		meta.ing.exit_idx = (bit<8>) random_t;
		if(hdr.ipv4.ttl < 3)
			meta.ing.exit_idx = 0xff;
	}
	action drop_walk (bit<32> dst_ip, bit<48> dst_mac){
		standard_metadata.egress_spec = 0;
		hdr.ipv4.dstAddr = dst_ip;
		hdr.ethernet.dstAddr = dst_mac;
	}
	table switchid {
		actions = {
			set_info;
			NoAction;
		}
		key = {
			hdr.icmp.type: exact;
		}
		size = 4;
		default_action = NoAction();
	}
	table rnd_wlk {
		actions = {
			set_nhop;
			drop_walk;
			NoAction;
		}
		key = {
			meta.ing.exit_idx: exact;
		}
		size = 256;
		default_action = NoAction();
	}
	table ipv4_lpm {
		actions = {
			set_nhop;
			NoAction;
		}
		key = {
			hdr.ipv4.dstAddr: lpm;
		}
		size = 1024;
		default_action = NoAction();
	}
	apply {
		if (hdr.ipv4.isValid()) {
			if(hdr.icmp.isValid()) {
				if(switchid.apply().hit)
					rnd_wlk.apply();
				else
					ipv4_lpm.apply();
			}else	
				ipv4_lpm.apply();
			
		}
	}
}

V1Switch(
	ParserImpl(), 
	verifyChecksum(), 
	ingress(), 
	egress(), 
	computeChecksum(), 
	DeparserImpl()
) main;

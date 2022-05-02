#include <core.p4>
#include <v1model.p4>

#include "header.p4"
#include "parser.p4"

control egress(inout headers hdr, inout metadata meta, inout standard_metadata_t standard_metadata) {
	action snd_src() {
		hdr.icmp.type = ICMP_ECHO_REPLY;
		hdr.ipv4.ttl = 0x40;
		bit<32> tmp = hdr.ipv4.srcAddr;
		hdr.ipv4.srcAddr = hdr.ipv4.dstAddr;
		hdr.ipv4.dstAddr = tmp;
	}
	table snd_INT {
		actions = {
			snd_src;
			NoAction;
		}
		key = {
			hdr.int_info.size: 	exact;
		}
		size = 256;
		default_action = NoAction();
	}
	apply {
		{
			bit<8> int_index = hdr.int_info.size - 1;
			hdr.ints[int_index].value = standard_metadata.egress_global_timestamp - meta.ing.ingress_time;
		}
		if(hdr.int_info.isValid())
			if(hdr.icmp.type == ICMP_ECHO_REQUEST)
				snd_INT.apply();
	}
}

control ingress(inout headers hdr, inout metadata meta, inout standard_metadata_t standard_metadata) {
	register<bit<48>>(1) myReg;
	register<bit<48>>(1) lastTime;

	action doDrop() {
		mark_to_drop(standard_metadata);
	}
	action set_nhop(bit<9> port) {
		standard_metadata.egress_spec = port;
		hdr.ipv4.ttl = hdr.ipv4.ttl + 8w255;
	}
	action set_info (bit<8> _size, bit<8> _id){
		meta.ing.max_idx = _size;
		bit<32> random_t;
        random(random_t, (bit<32>)0, (bit<32>)_size);
		meta.ing.exit_idx = (bit<8>) random_t;
		bit<8> int_index = hdr.int_info.size;
		hdr.int_info.size = int_index + 8w1;
		
		hdr.ints[int_index].setValid();
		hdr.ints[int_index].type = INT_RTT;
		hdr.ints[int_index].code = _id;
		// hdr.ints[int_index].value = standard_metadata.ingress_global_timestamp;
		bit<48>pkt_cnt;
		myReg.read(pkt_cnt, 0);
		hdr.ints[int_index].value = pkt_cnt;
		// hdr.ints[int_index].value = 0xF5F4F3F2F1F0;
		hdr.ints[int_index].is_valid = 0x01;

		hdr.ipv4.totalLen = hdr.ipv4.totalLen + INT_HEADER_LEN;
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
		meta.ing.ingress_time = standard_metadata.ingress_global_timestamp;
		bit<48>last_time;
		lastTime.read(last_time, 0);
		if(standard_metadata.ingress_global_timestamp - last_time > 100000){
			lastTime.write(0, standard_metadata.ingress_global_timestamp);
			myReg.write(0, 0);
		}
		bit<48>pkt_cnt;
		myReg.read(pkt_cnt, 0);
		pkt_cnt = pkt_cnt + 1;
		myReg.write(0, pkt_cnt);

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

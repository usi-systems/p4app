#include <core.p4>
#include <v1model.p4>

#include "header.p4"
#include "parser.p4"

control egress(inout headers hdr, inout metadata meta, inout standard_metadata_t standard_metadata) {
	action rewrite_mac(bit<48> smac) {
		hdr.ethernet.srcAddr = smac;
	}
	table send_frame {
		actions = {
			rewrite_mac;
			NoAction;
		}
		key = {
			standard_metadata.egress_port: exact;
		}
		size = 256;
		default_action = NoAction();
	}
	apply {
		if (hdr.ipv4.isValid()) {
		  send_frame.apply();
		}
	}
}

control ingress(inout headers hdr, inout metadata meta, inout standard_metadata_t standard_metadata) {
	register<bit<9>>(256) my_ports;
	register<bit<8>>(1) port_size;
	register<bit<8>>(1) last_idx;

	action doDrop() {
		mark_to_drop(standard_metadata);
	}
	action set_nhop(bit<9> port) {
		standard_metadata.egress_spec = port;
		hdr.ipv4.ttl = hdr.ipv4.ttl + 8w255;
	}
	action round_robin(){
		port_size.read(meta.ing.max_idx, 0); // read maximum index for ports
		last_idx.read(meta.ing.last_port_idx, 0); // read last used port index
		meta.ing.last_port_idx = meta.ing.last_port_idx + 1; // increment the port index
		if(meta.ing.last_port_idx > meta.ing.max_idx) // set index to zero if it's larger the maximum
			meta.ing.last_port_idx = 0;
		last_idx.write(0, meta.ing.last_port_idx); // saving ghte last index in the register.

		my_ports.read(standard_metadata.egress_spec, (bit<32>)meta.ing.last_port_idx); // set the exit port!
		hdr.ipv4.ttl = hdr.ipv4.ttl + 8w255;
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
		if(hdr.icmp.isValid() && hdr.icmp.type == ICMP_ECHO_REQUEST) {
			round_robin();
		}else if (hdr.ipv4.isValid()) {
			ipv4_lpm.apply();
		}
	}
}

V1Switch(ParserImpl(), verifyChecksum(), ingress(), egress(), computeChecksum(), DeparserImpl()) main;

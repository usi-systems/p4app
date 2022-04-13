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
    action doDrop() {
        mark_to_drop(standard_metadata);
    }
    action set_nhop(bit<9> port) {
        standard_metadata.egress_spec = port;
        hdr.ipv4.ttl = hdr.ipv4.ttl + 8w255;
    }
    action echo() {
        standard_metadata.egress_port = standard_metadata.ingress_port;
        hdr.ipv4.ttl = 0x13;
    }
    table self_ip {
        actions = {
            echo;
            NoAction;
        }
        key = {
            hdr.ipv4.dstAddr: exact;
        }
        size = 1024;
        default_action = NoAction();
    }
    table ipv4_lpm {
        actions = {
            doDrop;
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
            if(self_ip.apply().miss){
                ipv4_lpm.apply();
            }
        }
    }
}

V1Switch(ParserImpl(), verifyChecksum(), ingress(), egress(), computeChecksum(), DeparserImpl()) main;

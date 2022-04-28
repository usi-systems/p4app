parser ParserImpl(packet_in packet, out headers hdr, inout metadata meta, inout standard_metadata_t standard_metadata) {
    state parse_ethernet {
        packet.extract(hdr.ethernet);
        transition select(hdr.ethernet.etherType) {
            16w0x800: parse_ipv4;
            default: accept;
        }
    }
    state parse_ipv4 {
        packet.extract(hdr.ipv4);

        transition select(hdr.ipv4.protocol){
            PROTO_TCP: tcp;
            PROTO_UDP: udp;
            PROTO_ICMP: icmp;
            default: accept;
        }
    }
    state tcp {
        packet.extract(hdr.tcp);
        transition accept;
    }

    state udp {
        packet.extract(hdr.udp);
        transition accept;
    }
    state icmp {
        packet.extract(hdr.icmp);
        transition select(hdr.icmp.type){
            ICMP_ECHO_REQUEST: int_info;
            default: accept;
        }
    }
    state int_info {
        packet.extract(hdr.int_info);
        transition select(packet.lookahead<bit<8>>()) {
            8w0x0: accept;          // no valid entry!
            default: int_entry;     // there is a valid entry
        }
    }
    state int_entry {
        packet.extract(hdr.ints.next);
        transition select(packet.lookahead<bit<8>>()) {
            8w0x0: accept;          // no valid entry!
            default: int_entry;     // this creates a loop!
        }
    }
    state start {
        transition parse_ethernet;
    }
}

control DeparserImpl(packet_out packet, in headers hdr) {
    apply {
        packet.emit(hdr.ethernet);
        packet.emit(hdr.ipv4);
        packet.emit(hdr.icmp);
        packet.emit(hdr.int_info);
        packet.emit(hdr.ints);
        packet.emit(hdr.tcp);
        packet.emit(hdr.udp);
    }
}

control verifyChecksum(inout headers hdr, inout metadata meta) {
    apply { }
}

control computeChecksum(inout headers hdr, inout metadata meta) {
    apply {
        update_checksum(
                hdr.ipv4.isValid(),
                { hdr.ipv4.version, hdr.ipv4.ihl, hdr.ipv4.diffserv,
                hdr.ipv4.totalLen, hdr.ipv4.identification,
                hdr.ipv4.flags, hdr.ipv4.fragOffset, hdr.ipv4.ttl,
                hdr.ipv4.protocol, hdr.ipv4.srcAddr, hdr.ipv4.dstAddr },
                hdr.ipv4.hdrChecksum,
                HashAlgorithm.csum16);
    }
}


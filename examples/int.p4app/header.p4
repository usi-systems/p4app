#ifndef __HEADER_P4__
#define __HEADER_P4__ 1

const bit<8>  PROTO_ICMP = 1;
const bit<8>  PROTO_TCP  = 6;
const bit<8>  PROTO_UDP  = 17;

const bit<8>  ICMP_ECHO_REPLY    = 0;
const bit<8>  ICMP_ECHO_REQUEST  = 8;


const bit<8>  INT_BUFFER        = 0x04;
const bit<8>  INT_RTT           = 0x05;
const bit<16>  INT_HEADER_LEN    = 0x9;

struct ingress_metadata_t {
    bit<8> max_idx;
    bit<8> exit_idx;
}

header ethernet_t {
    bit<48> dstAddr;
    bit<48> srcAddr;
    bit<16> etherType;
}

header ipv4_t {
    bit<4>  version;
    bit<4>  ihl;
    bit<8>  diffserv;
    bit<16> totalLen;
    bit<16> identification;
    bit<3>  flags;
    bit<13> fragOffset;
    bit<8>  ttl;
    bit<8>  protocol;
    bit<16> hdrChecksum;
    bit<32> srcAddr;
    bit<32> dstAddr;
}
header tcp_t{
    bit<16> src_port;
    bit<16> dst_port;
    int<32> seqNo;
    int<32> ackNo;
    bit<4>  data_offset;
    bit<4>  res;
    bit<1>  cwr;
    bit<1>  ece;
    bit<1>  urg;
    bit<1>  ack;
    bit<1>  psh;
    bit<1>  rst;
    bit<1>  syn;
    bit<1>  fin;
    bit<16> window;
    bit<16> checksum;
    bit<16> urgentPtr;
}

header udp_t {
    bit<16> src_port;
    bit<16> dst_port;
    bit<16> payload_length;
    bit<16> checksum;
}
header icmp_t {
    bit<8>  type;
    bit<8>  code;
    bit<16> checksum;
}
header int_entry_t {
    bit<8>  is_valid;
    bit<8>  type;
    bit<8>  code;
    bit<48> value;
}
header int_info_t {
    bit<8>  size;
}
struct metadata {
    ingress_metadata_t   ing;
}
struct headers {
    ethernet_t          ethernet;
    ipv4_t              ipv4;
    icmp_t              icmp;
    int_info_t          int_info;
    int_entry_t[20]     ints;
    tcp_t               tcp;
    udp_t               udp;
}

#endif // __HEADER_P4__

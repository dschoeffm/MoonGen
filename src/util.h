#include <stdint.h>
#include <rte_config.h>
#include <rte_ip.h>
#include <rte_udp.h>
#include <rte_byteorder.h>
#include <rte_mbuf.h>
#include <rte_memcpy.h>
#include <rte_lcore.h>

//static inline uint16_t get_ipv4_psd_sum (struct ipv4_hdr* ip_hdr);

// TODO: cope with flexible offsets
// offset: udp - 20; tcp - 25
void calc_ipv4_pseudo_header_checksum(void* data, int offset);

void calc_ipv4_pseudo_header_checksums(struct rte_mbuf** data, int n, int offset);

void nm_calc_ipv4_pseudo_header_checksums(struct rte_mbuf** data, int n, int offset, int numSlots, int pos, uint64_t ol_flags, uint64_t tx_offload);

// TODO: cope with flexible offsets and different protocols
// offset: udp - 30; tcp - 35
void calc_ipv6_pseudo_header_checksum(void* data, int offset);

void calc_ipv6_pseudo_header_checksums(struct rte_mbuf** data, int n, int offset);

void nm_calc_ipv6_pseudo_header_checksums(struct rte_mbuf** data, int n, int offset, int numSlots, int pos, uint64_t ol_flags, uint64_t tx_offload);

void nm_set_offload_flags(struct rte_mbuf** data, int n, int numSlots, int pos, uint64_t ol_flags, uint64_t tx_offload);

// rte_lcore/socket_id are static in rte_lcore.h
uint32_t get_current_core();

uint32_t get_current_socket();


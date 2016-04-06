#include <net/netmap_user.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <sys/ioctl.h>
#include <sys/mman.h>
#include <poll.h>
#include <sys/socket.h>
#include <ifaddrs.h>
#include <stddef.h>
#include <string.h>
#include <linux/if_packet.h> 

// packets/mbufs
struct rte_pktmbuf {
	struct rte_mbuf* next;
	void* data;
	uint16_t data_len;
	uint8_t nb_segs;
	uint8_t in_port;
	uint32_t pkt_len;
	//union {
	uint16_t header_lengths;
	uint16_t vlan_tci;
	//uint32_t value;
	//} offsets;
	union {
		uint32_t rss;
		struct {
			uint16_t hash;
			uint16_t id;
		} fdir;
		uint32_t sched;
	} hash;
};

union rte_ipsec {
	uint32_t data;
	//struct {
	//      uint16_t sa_idx:10;
	//      uint16_t esp_len:9;
	//      uint8_t type:1;
	//      uint8_t mode:1;
	//      uint16_t unused:11; /**< These 11 bits are unused. */
	//} sec;
};

struct rte_mbuf {
	void* pool;
	void* data;
	uint64_t phy_addr;
	uint16_t len;
	uint16_t refcnt;
	uint8_t type;
	uint8_t reserved;
	uint16_t ol_flags;
	struct rte_pktmbuf pkt;
	union rte_ipsec ol_ipsec;
};

static struct nm_devices {
	struct nm_device* dev[64];
	int num_devs;
} nm_devs;

struct nm_device{
	struct nm_ring* nm_ring[64];
	struct nmreq nmr;
	uint32_t tx_pkts;
	uint32_t rx_pkts;
	uint64_t tx_octetts;
	uint64_t rx_octetts;
};

struct nm_ring{
	int fd;
	struct netmap_if* nifp;
	struct rte_mbuf* mbufs_tx[2048];
	struct rte_mbuf* mbufs_rx[2048];
	struct nm_device* dev;
};

struct nm_config_struct{
	char port[16];
	uint16_t txQueues;
	uint16_t rxQueues;
};

static void* netmap_mmap = NULL;


void hexdump(uint8_t* p, unsigned int bytes);
struct netmap_if* NETMAP_IF_wrapper(void* base, uint32_t ofs);
struct netmap_ring* NETMAP_TXRING_wrapper(struct netmap_if* nifp, uint32_t index);
struct netmap_ring* NETMAP_RXRING_wrapper(struct netmap_if* nifp, uint32_t index);
char* NETMAP_BUF_wrapper(struct netmap_ring* ring, uint32_t index);
char* NETMAP_BUF_smart_wrapper(struct netmap_ring* ring, uint32_t index);
uint64_t NETMAP_BUF_IDX_wrapper(struct netmap_ring* ring, char* buf);
int ioctl_NIOCGINFO(int fd, struct nmreq* nmr);
int ioctl_NIOCREGIF(int fd, struct nmreq* nmr);
int ioctl_NIOCTXSYNC(int fd);
int ioctl_NIOCRXSYNC(int fd);
/*
uint32_t update_tx_pkts_counter(struct nm_device* dev, uint32_t count);
uint32_t update_rx_pkts_counter(struct nm_device* dev, uint32_t count);
uint64_t update_tx_octetts_counter(struct nm_device* dev, uint64_t count);
uint64_t update_rx_octetts_counter(struct nm_device* dev, uint64_t count);
*/
int get_mac(char* ifname, uint8_t* mac); // No BSD
struct rte_mbuf** nm_alloc_mbuf_array(uint32_t num);
void mbufs_len_update(struct nm_device* dev, uint16_t ringid, uint32_t start, uint32_t count, uint16_t len);
void mbufs_slots_update(struct nm_device* dev, uint16_t ringid, uint32_t start, uint32_t count);
struct nm_device* nm_get(const char port[]);
static int nm_reopen(uint16_t ringid, struct nm_device* dev);
struct nm_device* nm_config(struct nm_config_struct* config);

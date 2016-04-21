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

struct rte_mbuf;
union rte_ipsec {
	uint32_t data;
};

struct rte_mbuf {
	void *buf_addr;           /**< Virtual address of segment buffer. */
	void *buf_physaddr; /**< Physical address of segment buffer. */

	uint16_t buf_len;         /**< Length of segment buffer. */

	/* next 6 bytes are initialised on RX descriptor rearm */
	uint16_t data_off;

	uint16_t refcnt;
	uint8_t nb_segs;          /**< Number of segments. */
	uint8_t port;             /**< Input port. */

	uint64_t ol_flags;        /**< Offload features. */
	/* remaining bytes are set on RX when pulling packet from descriptor */

	/*
	 * The packet type, which is the combination of outer/inner L2, L3, L4
	 * and tunnel types.
	 */
	uint32_t packet_type; /**< L2/L3/L4 and tunnel information. */

	uint32_t pkt_len;         /**< Total pkt len: sum of all segments. */
	uint16_t data_len;        /**< Amount of data in segment buffer. */
	uint16_t vlan_tci;        /**< VLAN Tag Control Identifier (CPU order) */

	union {
		uint32_t rss;     /**< RSS hash result if RSS enabled */
		struct {
			union {
				struct {
					uint16_t hash;
					uint16_t id;
				};
				uint32_t lo;
				/**< Second 4 flexible bytes */
			};
			uint32_t hi;
			/**< First 4 flexible bytes or FD ID, dependent on
		     PKT_RX_FDIR_* flag in ol_flags. */
		} fdir;           /**< Filter identifier if FDIR enabled */
		struct {
			uint32_t lo;
			uint32_t hi;
		} sched;          /**< Hierarchical scheduler */
		uint32_t usr;	  /**< User defined tags. See rte_distributor_process() */
	} hash;                   /**< hash information */

	uint32_t seqn; /**< Sequence number. See also rte_reorder_insert() */

	uint16_t vlan_tci_outer;  /**< Outer VLAN Tag Control Identifier (CPU order) */

	/* second cache line - fields only used in slow path or on TX */

	uint64_t udata64;

	struct rte_mempool *pool; /**< Pool from which mbuf was allocated. */
	struct rte_mbuf *next;    /**< Next segment of scattered packet. */

	/* fields to support TX offloads */
	uint64_t tx_offload;

	/** Size of the application private data. In case of an indirect
	 * mbuf, it stores the direct mbuf private data size. */
	uint16_t priv_size;

	/** Timesync flags for use with IEEE1588. */
	uint16_t timesync;

	/* Chain of off-load operations to perform on mbuf */
	struct rte_mbuf_offload *offload_ops;
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
void print_pointer(void* p);
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
int get_mac(char* ifname, char* mac); // No BSD
struct rte_mbuf** nm_alloc_mbuf_array(uint32_t num);
void mbufs_len_update(struct nm_device* dev, uint16_t ringid, uint32_t start, uint32_t count, uint16_t len);
void mbufs_slots_update(struct nm_device* dev, uint16_t ringid, uint32_t start, uint32_t count);
void slot_mbuf_update(struct nm_device* dev, uint16_t ringid, uint32_t start, uint32_t count);
uint32_t fetch_tx_pkts(struct nm_device* dev);
uint32_t fetch_rx_pkts(struct nm_device* dev);
uint64_t fetch_tx_octetts(struct nm_device* dev);
uint64_t fetch_rx_octetts(struct nm_device* dev);
struct nm_device* nm_get(const char port[]);
static int nm_reopen(uint16_t ringid, struct nm_device* dev);
struct nm_device* nm_config(struct nm_config_struct* config);

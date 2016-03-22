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
#include <linux/if_packet.h> //No BSD

struct netmap_if* NETMAP_IF_wrapper(void* base, uint32_t ofs){
	return NETMAP_IF(base, ofs);
}

struct netmap_ring* NETMAP_TXRING_wrapper(struct netmap_if* nifp, uint32_t index){
	return NETMAP_TXRING(nifp, index);
}

struct netmap_ring* NETMAP_RXRING_wrapper(struct netmap_if* nifp, uint32_t index){
	return NETMAP_RXRING(nifp, index);
}

char* NETMAP_BUF_wrapper(struct netmap_ring* ring, uint32_t index){
	return NETMAP_BUF(ring, index);
}

uint64_t NETMAP_BUF_IDX_wrapper(struct netmap_ring* ring, char* buf){
	return NETMAP_BUF_IDX(ring, buf);
}

int open_wrapper(){
	return open("/dev/netmap", O_RDWR);
}

void* mmap_wrapper(uint32_t memsize, int fd){
	return mmap(NULL , memsize, PROT_READ | PROT_WRITE, MAP_SHARED, fd, 0);
}

int ioctl_NIOCGINFO(int fd, struct nmreq* nmr){
	return ioctl(fd, NIOCGINFO, nmr);
}

int ioctl_NIOCREGIF(int fd, struct nmreq* nmr){
	return ioctl(fd, NIOCREGIF, nmr);
}

int ioctl_NIOCTXSYNC(int fd){
	return ioctl(fd, NIOCTXSYNC);
}

int ioctl_NIOCRXSYNC(int fd){
	return ioctl(fd, NIOCRXSYNC);
}

int get_mac(char* ifname, uint8_t* mac){ // No BSD
	struct ifaddrs* ifap;
	int ret = getifaddrs(&ifap);
	struct ifaddrs* head = ifap;
	if(ret != 0){
		return -1;
	}
	while(ifap != NULL){
		if(strncmp(ifname, ifap->ifa_name, 16) == 0){
			struct sockaddr_ll* ll = (struct sockaddr_ll*) ifap->ifa_addr;
			memcpy(mac, ll->sll_addr, 6);
			return 0;
		}
		ifap = ifap->ifa_next;
	}
	freeifaddrs(head);
	return -1;
}

#include <net/netmap_user.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <sys/ioctl.h>
#include <sys/mman.h>
#include <poll.h>

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
	return mmap(0 , memsize, PROT_READ | PROT_WRITE, MAP_SHARED, fd, 0);
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

---------------------------------
--- @file netmapc.lua
--- @brief c definitions from header
--- @todo TODO docu
-- most of this file is copy-pasted from:
-- https://github.com/luigirizzo/netmap/blob/master/sys/net/netmap.h
-- written by Matteo Landi, Luigi Rizzo
---------------------------------
-- original license of the above file:
--[[ /*
 * Copyright (C) 2011-2014 Matteo Landi, Luigi Rizzo. All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 *
 *   1. Redistributions of source code must retain the above copyright
 *      notice, this list of conditions and the following disclaimer.
 *   2. Redistributions in binary form must reproduce the above copyright
 *      notice, this list of conditions and the following disclaimer in the
 *      documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS ``S IS''AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED. IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 */
--]]


local ffi = require "ffi"

-- structs
ffi.cdef[[
// API version
enum api{
	NETMAP_API = 11,
	NETMAP_MIN_API = 11,
	NETMAP_MAX_API = 15,
};

static const int NM_CACHE_ALIGN = 128; 

// struct netmap_slot is a buffer descriptor
struct netmap_slot {
	uint32_t buf_idx;	/* buffer index */
	uint16_t len;		/* length for this slot */
	uint16_t flags;		/* buf changed, etc. */
	uint64_t ptr;		/* pointer for indirect buffers */
};

static const uint16_t NS_BUF_CHANGED = 0x0001;
static const uint16_t NS_REPORT = 0x0002;
static const uint16_t NS_FORWARD = 0x0004;
static const uint16_t NS_NO_LEARN = 0x0008;
static const uint16_t NS_INDIRECT = 0x0010;
static const uint16_t NS_MOREFRAG = 0x0020;

static const uint16_t NS_PORT_SHIFT = 8;
static const uint16_t NS_PORT_MASK = 0xff00;

// struct netmap_ring defines one ring of a NIC or host ring
struct netmap_ring {
	const int64_t buf_ofs;
	const uint32_t num_slots; /* number of slots in the ring. */
	const uint32_t nr_buf_size;
	const uint16_t ringid;
	const uint16_t dir; /* 0: tx, 1: rx */
	uint32_t head;  /* (u) first user slot */
	uint32_t cur;   /* (u) wakeup point */
	uint32_t tail;  /* (k) first kernel slot */
	uint32_t flags;
	struct timeval	ts;		/* (k) time of last *sync() */
	uint8_t	__attribute__((__aligned__(NM_CACHE_ALIGN))) sem[128];
	struct netmap_slot slot[0];	/* array of slots. */
};

static const uint16_t NR_TIMESTAMP = 0x0002;
static const uint16_t NR_FORWARD = 0x0004;

// struct netmap_if defines one interface and refers to rings
struct netmap_if {
	char		ni_name[16]; /* name of the interface. */ // originally IFNAMSIZ instead of 16
	const uint32_t	ni_version;	/* API version, currently unused */
	const uint32_t	ni_flags;	/* properties */
	const uint32_t	ni_tx_rings;	/* number of HW tx rings */
	const uint32_t	ni_rx_rings;	/* number of HW rx rings */
	uint32_t	ni_bufs_head;	/* head index for extra bufs */
	uint32_t	ni_spare1[5];
	const uint64_t	ring_ofs[0]; // originally ssize_t
};

static const uint16_t NI_PRIV_MEM = 0x1;

//struct nmreq defines the request for a netmap device
struct nmreq {
	char		nr_name[16];
	uint32_t	nr_version;	/* API version */
	uint32_t	nr_offset;	/* nifp offset in the shared region */
	uint32_t	nr_memsize;	/* size of the shared region */
	uint32_t	nr_tx_slots;	/* slots in tx rings */
	uint32_t	nr_rx_slots;	/* slots in rx rings */
	uint16_t	nr_tx_rings;	/* number of tx rings */
	uint16_t	nr_rx_rings;	/* number of rx rings */
	uint16_t	nr_ringid;	/* ring(s) we care about */
	uint16_t	nr_cmd;
	uint16_t	nr_arg1;	/* reserve extra rings in NIOCREGIF */
	uint16_t	nr_arg2;
	uint32_t	nr_arg3;	/* req. extra buffers in NIOCREGIF */
	uint32_t	nr_flags;
	uint32_t	spare2[1];
};

static const uint16_t NETMAP_HW_RING = 0x4000;
static const uint16_t NETMAP_SW_RING = 0x2000;
static const uint16_t NETMAP_RING_MASK = 0x0fff;
static const uint16_t NETMAP_NO_TX_POLL = 0x1000;
static const uint16_t NETMAP_DO_RX_POLL = 0x8000;

static const uint16_t NETMAP_BDG_ATTACH = 1;
static const uint16_t NETMAP_BDG_DETACH = 2;
static const uint16_t NETMAP_BDG_REGOPS = 3;
static const uint16_t NETMAP_BDG_LIST = 4;
static const uint16_t NETMAP_BDG_VNET_HDR = 5;
static const uint16_t NETMAP_BDG_OFFSET = 5; // same as NETMAP_BDG_VNET_HDR
static const uint16_t NETMAP_BDG_NEWIF = 6;
static const uint16_t NETMAP_BDG_DELIF = 7;
static const uint16_t NETMAP_PT_HOST_CREATE = 8;
static const uint16_t NETMAP_PT_HOST_DELETE = 9;
static const uint16_t NETMAP_BDG_POLLING_ON = 10;
static const uint16_t NETMAP_BDG_POLLING_OFF = 11;
static const uint16_t NETMAP_VNET_HDR_GET = 12;
static const uint16_t NETMAP_BDG_HOST = 13;

static const uint16_t NR_REG_MASK = 0xf;

enum {	NR_REG_DEFAULT	= 0,	/* backward compat, should not be used. */
	NR_REG_ALL_NIC	= 1,
	NR_REG_SW	= 2,
	NR_REG_NIC_SW	= 3,
	NR_REG_ONE_NIC	= 4,
	NR_REG_PIPE_MASTER = 5,
	NR_REG_PIPE_SLAVE = 6,
};

static const uint16_t NR_MONITOR_TX = 0x100;
static const uint16_t NR_MONITOR_RX = 0x200;
static const uint16_t NR_ZCOPY_MON = 0x400;
static const uint16_t NR_EXCLUSIVE = 0x800;
static const uint16_t NR_PASSTHROUGH_HOST = 0x1000; // same as NR_PTNETMAP_HOST
static const uint16_t NR_PTNETMAP_HOST = 0x1000;
static const uint16_t NR_RX_RINGS_ONLY = 0x2000;
static const uint16_t NT_TX_RINGS_ONLY = 0x4000;
static const uint16_t NR_ACCEPT_VNET_HDR = 0x8000;

// extracted from sample program
/* now done via c libary
static const unsigned long NIOCGINFO = 3225184657;
static const unsigned long NIOCREGIF = 3225184658;
static const unsigned long NIOCTXSYNC = 27028;
static const unsigned long NIOCRXSYNC = 27029;
static const unsigned long NIOCCONFIG = 3239078294;
*/
]]

-- functions provided by C libary
ffi.cdef[[
struct netmap_if* NETMAP_IF_wrapper(uint64_t base, uint32_t ofs);
struct netmap_ring* NETMAP_TXRING_wrapper(struct netmap_if* nifp, uint32_t index);
struct netmap_ring* NETMAP_RXRING_wrapper(struct netmap_if* nifp, uint32_t index);
char* NETMAP_BUF_wrapper(struct netmap_ring* ring, uint32_t index);
uint64_t NETMAP_BUF_IDX_wrapper(struct netmap_ring* ring, char* buf);

int open_wrapper();
int ioctl_NIOCGINFO(int fd, struct nmreq* nmr);
int ioctl_NIOCREGIF(int fd, struct nmreq* nmr);
int ioctl_NIOCTXSYNC(int fd);
int ioctl_NIOCRXSYNC(int fd);

/*
struct netmap_if* NETMAP_IF(_base, _ofs);
struct netmap_ring* NETMAP_TXRING(nifp, index);
struct netmap_ring* NETMAP_RXRING(nifp, index);
char* NETMAP_BUF(ring, index);
uing32_t NETMAP_BUF_IDX(ring, buf);
*/
]]

-- functions and constants from the c stdlib and linux
ffi.cdef[[
//int open(const char *pathname, int flags, mode_t mode);
//int ioctl(int fd, unsigned long request, ...);
void *mmap(void *addr, size_t length, int prot, int flags, int fd, uint64_t offset); // originally off_t
//int poll(struct pollfd *fds, nfds_t nfds, int timeout);

// from man 2 poll
struct pollfd {
	int   fd;         /* file descriptor */
	short events;     /* requested events */
	short revents;    /* returned events */
};

static const int O_RDWR = 00000002; ///usr/include/asm-generic/fcntl.h

// from /usr/include/asm-generic/mman-common.h
static const int PROT_READ = 0x1;
static const int PROT_WRITE = 0x2;
static const int PROT_READ_WRITE = 0x3; // this is my own
static const int PROT_EXEC = 0x4;
static const int PROT_SEM = 0x8;
static const int PROT_NONE = 0x0;
static const int MAP_SHARED = 0x1;
static const int MAP_PRIVATE = 0x2;
]]


return ffi.C

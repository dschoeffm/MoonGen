---------------------------------
--- @file memoryDevice.lua
--- @brief High level device/NIC/port management for Netmap
--- @todo feature level of DPDK
---------------------------------

local netmapc = require "netmapc"
local ffi = require "ffi"
local log = require "log"

local mod = {} -- local module

----------------------------------------------------------------------------------
---- Netmap Device
----------------------------------------------------------------------------------

local dev = {}
dev.__index = dev
mod.devices = {}

local txQueue = {}
txQueue.__index = txQueue

local rxQueue = {}
rxQueue.__index = rxQueue

mod.mmaped = false
mod.mem = 0

--- Opens the netmap device (helper function, internal use only)
--- @param self: device object
--- @param ringid: index of the requested ring
local function openDevice(self, ringid)
	if not ringid or self.fd[ringid] then
		log:error("no ringid was given, or ring was opened already")
		return nil
	end
	-- open the netmap control file
	--local fd = netmapc.open("/dev/netmap", O_RDWR)
	log:debug("opening /dev/netmap now")
	local fd = netmapc.open_wrapper()
	if fd == -1 then
		log:fatal("Error opening /dev/netmap")
		return nil
	end

	-- create request and populate it from the config
	local nmr = ffi.new("struct nmreq[1]")
	self.nmr = nmr
	nmr[0].nr_name = self.iface
	nmr[0].nr_version = netmapc.NETMAP_API
	nmr[0].nr_flags = netmapc.NR_REG_ONE_NIC
	nmr[0].nr_ringid = ringid -- TODO NETMAP_NO_TX_POLL should be set
	-- not reliably supported anyways
	--nmr.nr_tx_rings = config.nr_tx_rings
	--nmr.nr_rx_rings = config.nr_rx_rings
	--nmr.nr_tx_slots = config.nr_tx_slots
	--nmr.nr_rx_slots = config.nr_rx_slots

	-- do ioctl to register the device
	--local ret = netmapc.ioctl(fd, NIOCREGIF, nmr)
	log:debug("issuing NIOCREGIF now")
	local ret = netmapc.ioctl_NIOCREGIF(fd, nmr)
	if ret == -1 then
		log:fatal("Error issuing NIOCREGIF")
		return nil
	end

	-- mmap if not happend before
	if not mod.mmaped then
		log:debug("memory mapping the DMA region now")
		mod.mem = netmapc.mmap(nil, nmr[0].nr_memsize, netmapc.PROT_READ_WRITE, netmapc.MAP_SHARED, fd, 0);
		mod.mmaped = true
	end

	self.mem = mod.mem
	self.fd[ringid] = fd
	self.nifp[ringid] = netmapc.NETMAP_IF_wrapper(mod.mem, nmr[0].nr_offset)
end

--- Configures a device
--- @param args.port: Interface name (eg. eth1)
--- @todo there are way more parameters with DPDK
--- @return Netmap device object
function mod.config(...)
	local args = {...}
	if type(args[1]) ~= "table" then
		log:fatal("Currently only tables are supported in netmapDevice.config()")
		return nil
	end
	args = args[1]

	-- create new device object
	local dev_ret = {}
	setmetatable(dev_ret, dev)
	dev_ret.iface = args.port
	dev_ret.fd = {}
	dev_ret.nifp = {}

	openDevice(dev_ret, 0)

	mod.devices[dev_ret.iface] = dev_ret

	return dev_ret
end

--- Get a already configured device
--- @param iface: interface name (eg. eth1)
--- @return Netmap device object
function mod.get(iface)
	if not mmaped then
		log:warn("get(iface) runs before config(...)")
		mod.config({port = iface})
	end
	local d = mod.devices[iface]
	if d == nil then
		log:fatal("tried to get uninitialized device: " .. iface)
	end
	return d
end

--- Wait for the links to come up
--- Does nothing at the moment
function dev:wait()
	-- do nothing for now
	-- waiting 2 seconds is probably the best we can do
	-- maybe there is a syscall like "ip l"?
end

--- Get the tx queue with a certain number
--- @param id: index of the queue
--- @return Netmap tx queue object
function dev:getTxQueue(id)
	if not (id < self.nmr[0].nr_tx_rings) then
		log:error("[ERROR] tx queue id is too high")
		return nil
	end
	if not self.fd[id] then
		log:info("open netmap device again - file descriptor does not exist yet")
		openDevice(self, id)
	end

	local queue = {}
	setmetatable(queue, txQueue)
	log:debug("getting tx ring now")
	queue.nmRing = netmapc.NETMAP_TXRING_wrapper(self.nifp[id], id) -- XXX is this correct? (seems to be)
	queue.fd = self.fd[id]
	return queue
end

--- Get the rx queue with a certain number
--- @param id: index of the queue
--- @return Netmap rx queue object
function dev:getRxQueue(id)
	if not (id < self.nmr[0].nr_rx_rings) then
		log:error("[ERROR] tx queue id is too high")
		return nil
	end
	if not self.fd[id] then
		self:openDevice(id)
	end

	local queue = {}
	setmetatable(queue, rxQueue)
	log:debug("getting rx ring now")
	queue.nmRing = netmapc.NETMAP_RXRING_wrapper(self.nifp[id], id) -- XXX is this correct? (seems to be)
	-- XXX set metatype?
	queue.fd = self.fd[id]
	return queue
end

----------------------------------------------------------------------------------
---- Netmap Tx Queue
----------------------------------------------------------------------------------

--- Sync the SW view with the HW view
function txQueue:sync()
	netmapc.ioctl_NIOCREGIF(self.fd)
end

--- Send the current buffer
--- @param bufs: packet buffers to send
function txQueue:send(bufs)
    self.nmRing.head = bufs.last
    self.nmRing.cur = self.head
    self.sync()
end

--- Return how many slots are available to the userspace
--- @return Number of available buffers
function txQueue:avail()
	ret = self.nmRing.tail - self.nmRing.cur
	if ret < 0 then
		ret = ret + ring.nmRing.num_slots
	end
	return ret
	--return netmapc.nm_ring_space(self.c) -- original c call
end

function txQueue:setRate(rate)
	-- do nothing for now
	-- is something like this supported at all?
end

ffi.metatype("struct netmap_ring", txQueue) -- XXX pointer or no pointer

----------------------------------------------------------------------------------
---- Netmap Rx Queue
----------------------------------------------------------------------------------

--- TODO
--ffi.metatype("struct netmap_ring*", rxQueue) -- Throws an error


return mod

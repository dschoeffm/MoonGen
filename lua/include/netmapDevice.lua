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

	-- set default values
	args.txQueues = args.txQueues or 1
	args.rxQueues = args.rxQueues or 1

	local config = ffi.new("struct nm_config_struct[1]")
	config[0].port = args.port
	config[0].txQueues = args.txQueues
	config[0].rxQueues = args.rxQueues

	-- create new device object
	local dev_ret = {}
	setmetatable(dev_ret, dev)
	dev_ret.port = args.port
	dev_ret.c = netmapc.nm_config(config)

	if dev_ret.c == nil then
		log:fatal("Something went wrong during netmapc.nm_config")
	end

	return dev_ret
end

--- Get a already configured device
--- @param iface: interface name (eg. eth1)
--- @return Netmap device object
function mod.get(port)
	local dev_ret = {}
	setmetatable(dev_ret, dev)
	dev_ret.c = netmapc.nm_get(port)
	dev_ret.port = port
	return dev_ret
end

--- Wait for the links to come up
function dev:wait()
	ffi.cdef[[
		int sleep(int seconds);
	]]
	ffi.C.sleep(5)
end

function mod.waitForLinks()
	ffi.cdef[[
		int sleep(int seconds);
	]]
	ffi.C.sleep(5)
end

--- Get the tx queue with a certain number
--- @param id: index of the queue
--- @return Netmap tx queue object
function dev:getTxQueue(id)
	if tonumber(self.c.fds[id]) == 0 then
		log:fatal("This queue was not configured")
	end

	local queue = {}
	setmetatable(queue, txQueue)
	queue.nmRing = netmapc.NETMAP_TXRING_wrapper(self.c.nifps[id], id)
	queue.fd = self.c.fds[id]
	queue.dev = self
	queue.id = id

	return queue
end

--- Get the rx queue with a certain number
--- @param id: index of the queue
--- @return Netmap rx queue object
function dev:getRxQueue(id)
	if tonumber(self.c.fds[id]) == 0 then
		log:fatal("This queue was not configured")
	end

	local queue = {}
	setmetatable(queue, rxQueue)
	queue.nmRing = netmapc.NETMAP_RXRING_wrapper(self.c.nifps[id], id)
	queue.fd = self.c.fds[id]
	queue.dev = self
	queue.id = id

	return queue
end


function dev:__tostring()
	return ("[Device: interface=%s]"):format(self.port)
end

function dev:__serialize()
	log:debug("dev:__serialize() iface=" .. self.port)
	return ('local dev= require "netmapDevice" return dev.get(%s)'):format(self.port), true
end


----------------------------------------------------------------------------------
---- Netmap Tx Queue
----------------------------------------------------------------------------------

--- Sync the SW view with the HW view
function txQueue:sync()
	netmapc.ioctl_NIOCTXSYNC(self.fd)
end

--- Send the current buffer
--- @param bufs: packet buffers to send
function txQueue:send(bufs)
	local b
	local e
	if bufs.first < bufs.last then
		b = bufs.first
		e = bufs.last
	else
		b = bufs.last
		e = bufs.first
	end
	for i=b,e do
		local mbuf = bufs.mem.mbufs[i]
		local len = mbuf.pkt.data_len
		bufs.mem.queue.nmRing[0].slot[i].len = len
	end

	self.nmRing[0].head = bufs.last
	self.nmRing[0].cur = self.nmRing[0].head
	self:sync()
end

--- Return how many slots are available to the userspace
--- @return Number of available buffers
function txQueue:avail()
	ret = self.nmRing.tail - self.nmRing.cur
	if ret < 0 then
		ret = ret + self.nmRing.num_slots
	end
	return ret
end

function txQueue:setRate(rate)
	-- do nothing for now
	-- is something like this supported at all?
end

function txQueue:__tostring()
	log:debug("txQueue:__tostring(): self.dev.iface=" .. self.port .. ", id=" .. self.id)
	return("[TxQueue: interface=%s, ringid=%d"):format(self.dev.port, self.id)
end

function txQueue:__serialize()
	return ('local dev = require "netmapDevice" return dev.get("%s"):getTxQueue(%d)'):format(self.dev.port, self.id), true
end

----------------------------------------------------------------------------------
---- Netmap Rx Queue
----------------------------------------------------------------------------------

--- TODO
--ffi.metatype("struct netmap_ring*", rxQueue) -- Throws an error


return mod

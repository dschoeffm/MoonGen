---------------------------------
--- @file memoryNetmap.lua
--- @brief High level memory management for Netmap
--- @todo feature level of DPDK
---------------------------------

local netmapc = require "netmapc"
local packet = require "packet"
local ffi = require "ffi"
local log = require "log"

local mod = {}

local mempool = {}
mempool.__index = mempool

local bufArray = {}
local mbufs = {}

-- local netmapSlot = {}
-- netmapSlot.__index = netmapSlot

----------------------------------------------------------------------------------
---- Memory Pool (Netmap edition)
----------------------------------------------------------------------------------

--- Prepares the "Memory Pool" (pre allocated by netmap)
--- Creates the rte_mbuf array for normal MoonGen usage
--- @param table with the following fields:
---	@param	.queue : A netmap queue object
--- @param  .func  : (optional) A function run on every packet buffer
--- @return  A Memory Pool object containing a rte_mbuf array
function mod.createMemPool(...)
	local args = {...}
	if type(args[1]) ~= "table" then
		log:fatal("Currently only tables are supported in netmapMemory.createMemPool()")
		return nil
	end
	args = args[1]
	if not args.queue then
		log:fatal("When using Netmap, a ring needs to be given in the .queue argument")
		return nil
	end
	if args.n or args.socket or args.bufSize then
		log:warn("You set variables intended for DPDK, they are ignored by netmap")
	end
	if args.queue.nmRing.num_slots ~= args.queue:avail() then
		log:warn("Packets left in the ring - probably not what you want")
	end

	local mem = {}
	setmetatable(mem, mempool)
	mem.queue = args.queue
	mem.mbufs = {}
	mem.mbufs.mem = mem
	setmetatable(mem.mbufs, mbufs)

--[[
	for i=0,args.queue.nmRing.num_slots -1 do
		if mem.queue.tx then
			mem.mbufs[i] = mem.queue.dev.c.nm_ring[mem.queue.id].mbufs_tx[i]
		else
			mem.mbufs[i] = mem.queue.dev.c.nm_ring[mem.queue.id].mbufs_rx[i]
		end
	end
--]]
	if args.func then
		for i=0,args.queue.nmRing.num_slots -1 do
			args.func(mem.mbufs[i])
		end
	end

	log:debug("return from createMemPool")

	return mem
end

function mbufs.__index(self, k)
	if self.mem.queue.tx then
		return self.mem.queue.dev.c.nm_ring[mem.queue.id].mbufs_tx[i]
	else
		return self.mem.queue.dev.c.nm_ring[mem.queue.id].mbufs_rx[i]
	end
end

--- This function returns a buffer array
--- @param n: number of packets inside of this buffer array
--- @return A buffer array object
function mempool:bufArray(n)
	n = n or 63
	if n > self.queue.nmRing.num_slots then
		log:fatal("not enough slots in the memory pool / ring - check your config")
		return nil
	end
	while self.queue:avail() < n do
		self.queue:sync()
	end
	log:debug("generating buffer array")
	local bufs = {
		size = n,
		maxSize = n,
		mem = self,
		mbufs = self.mbufs,
		queue = self.queue,
		dev = self.queue.dev,
		numSlots = self.queue.nmRing.num_slots,
		first = self.queue.nmRing.head, 
	}
	self.queue.bufs = bufs
	setmetatable(bufs, bufArray)
	return bufs
end

----------------------------------------------------------------------------------
---- Buffer Array
----------------------------------------------------------------------------------

--- Prepare the buffer array with the length of the packets
--- @param Length of the packets
function bufArray:alloc(len)
	-- no actual allocation, just update the the length fields
	-- wait until there is space in the ring
	local queue = self.queue
	while queue:avail() < self.maxSize do
		queue:sync()
	end
	self.first = queue.nmRing.head

	netmapc.mbufs_len_update(self.dev.c, self.queue.id, self.first, self.size, len);
end

function bufArray:freeAll()
	local newHead = self.first + self.size
	if newHead >= self.numSlots then
		newHead = newHead - self.numSlots
	end
	if newHead < 0 then
		log:fatal("tried setting head and cur to value < 0")
	end
	self.queue.nmRing.head = newHead
	self.queue.nmRing.cur = newHead
end

function bufArray.__index(self, k)
	if type(k) == "number" then
		if k + self.first -1 == self.numSlots then
			return self.mbufs[0]
		end
		return self.mbufs[k]
	else
		return bufArray[k]
	end
	-- too slow
	--return type(k) == "number" and self.mem.mbufs[(k+self.first-1)%self.maxSize] or bufArray[k]
end

function bufArray.__len(self)
	return self.size
end

do
	local function it(self, i) --TODO modulo wrap around
		if i+1 == self.numSlots then
			i = 0
		end
		if i == ((self.first + self.size)%self.numSlots) then
			return nil
		end
		return i + 1, self.mem.mbufs[i]
	end

	function bufArray.__ipairs(self)
		return it, self, self.first
	end
end

function bufArray.__tostring(self)
	return ("first=" .. self.first .. " size=" .. self.size .. " maxSize=" .. self.maxSize)
end


function bufArray:offloadUdpChecksums(ipv4, l2Len, l3Len)
	-- do nothing for now
end

function bufArray:offloadIPSec(idx, mode, sec_type)
	-- do nothing for now
end

function bufArray:offloadIPChecksums(ipv4, l2Len, l3Len, n)
	-- do nothing for now
end

function bufArray:offloadTcpChecksums(ipv4, l2Len, l3Len)
	-- do nothing for now
end

return mod

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
bufArray.__index = bufArray

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
	mem.queue = args.queue
	log:debug("allocating mbufs now")
	mem.mbufs = ffi.new("struct rte_mbuf[?]", args.queue.nmRing.num_slots)
	mem.slots = {}
	for i=0,args.queue.nmRing.num_slots do
		mem.mbufs[i].pkt.data = netmapc.NETMAP_BUF_wrapper(mem.queue.nmRing, i) 
		mem.slots[i] = mem.queue.nmRing.slot[i] -- XXX is this really saving a pointer?
		--setmetatable(mem.mbufs[i], packet) -- XXX is this correct?
	end

	if args.func then
		log:debug("running prepare functions on all mbufs")
		for i=0,args.queue.nmRing.num_slots do
			args.func(mem.mbufs[i])
		end
	end

	setmetatable(mem, mempool)

	return mem
end

--- This function returns a buffer array
--- @param n: number of packets inside of this buffer array
--- @return A buffer array object
function mempool:bufArray(n)
	n = n or 63
	self.batch_size = n
	if n > self.queue.nmRing.num_slots then
		log:fatal("not enough slots in the memory pool / ring - check your config")
		return nil
	end
	while self.queue:avail() < n do -- block / busy wait until array size is satisfied
		log:debug("mempool:bufArray waiting for buffer to be available")
		self.queue:sync()
	end
	log:debug("generating buffer array")
	return setmetatable({
		size = n,
		maxSize = n,
		array = 0, --TODO where will this be used afterall? (was there with DPDK)
		mem = self,
		first = self.queue.nmRing.head, 
		last = (self.queue.nmRing.head + n) % self.queue.nmRing.num_slots -- XXX if-then-else might be faster
	}, bufArray)
end

----------------------------------------------------------------------------------
---- Buffer Array
----------------------------------------------------------------------------------

--- Prepare the buffer array with the length of the packets
--- @param Length of the packets
function bufArray:alloc(len)
	-- no actual allocation, just update the the length fields
	-- wait until there is space in the ring
	local queue = self.mem.queue
	log:debug("avail = " .. queue:avail() .. ", len = " .. len)
	while queue:avail() < self.size do
		log:debug("bufArray:alloc waiting for buffer to be available")
		queue:sync()
	end
	self.first = queue.nmRing.head
	self.last = self.first + self.size
	if not (self.last < queue.nmRing.num_slots) then
		self.last = self.last - queue.nmRing.num_slots
	end
	log:debug("update the length fields")
	--for _, buf in ipairs(self) do -- TODO this needs rework
	--	buf.len = len -- XXX is this sufficient -> buf.data.data_len, buf.data.pkt_len
	--	buf.pkt.slot.len = len -- TODO this does not work
	--end
	local b
	local e
	if self.first < self.last then
		b = self.first
		e = self.last
	else
		b = self.last
		e = self.first
	end
	for i=b,e do
		local mbuf = self.mem.mbufs[i]
		mbuf.pkt.data_len = len
		self.mem.slots[i].len = len
	end
	log:debug("updating finished")
end

--[[ -- __index is defined like a class
function bufArray.__index(self, k)
	local num_slots = self.mem.queue.nmRing.num_slots
	if type(k) ~= "number" then
		return nil
	end
	if not (k < num_slots) then
		k = k - num_slots
	end
	return self.mem.mbufs[k - 1] or bufArray[k] -- no idea what that or does (copied from DPDK)
end
--]]

-- do I need bufArray.__newindex() ?

function bufArray._len(self)
	return self.size
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

--[[ XXX This class might not be of much use XXX
----------------------------------------------------------------------------------
---- Netmap slots (internal use only)
----------------------------------------------------------------------------------
local netmapSlot = {}
netmapSlot.__index = netmapSlot

--- Returns a netmap ring object
--- @param ring: a netmap ring
--- @param index: id of the slot
--- @return a netmap slot object
function netmapSlot:create(ring, index)
	r = ffi.cast("struct netmap_slot", ring.slot[index])
	setmetatable(r, self)
	r.ring = ring -- XXX Do I need this?
	return r
end

--- Get/Set the length of a packet
--- @param length: length of the packet described in this slot (optional)
--- @return Current value of the length field
function netmapSlot:len(length)
	if length ~= nil then
		self.len = length
	end
	return self.len
end

--- Get/Set flags of the packet
--- @param flags: new flags value, replacing the old one (optional)
--- @return Currently set flags
function netmapSlot:flags(flags)
	if flags ~= nil then
		self.flags = flags
	end
	return self.flags
end

ffi.metatype("struct netmap_slot", netmapSlot)
--]]
return mod

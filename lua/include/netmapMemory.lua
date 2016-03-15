---------------------------------
--- @file memoryNetmap.lua
--- @brief High level memory management for Netmap
--- @todo feature level of DPDK
---------------------------------

local netmapRing = require "netmapRing"
local netmapc = require "netmapc"
local packet = require "packet"
local ffi = require "ffi"
local netmapSlot = require "netmapSlot"

local mod = {}

----------------------------------------------------------------------------------
---- Memory Pool (Netmap edition)
----------------------------------------------------------------------------------

local mempool = {}
mempool.__index = mempool

--- Prepares the "Memory Pool" (pre allocated by netmap)
--- Creates the rte_mbuf array for normal MoonGen usage
--- @param table with the following fields:
---	@param	.queue : A netmap queue object
--- @param  .func  : (optional) A function run on every packet buffer
--- @return  A Memory Pool object containing a rte_mbuf array
function mod.createMemPool(...)
	local args = {...}
	if type(args[1]) ~= table then
		print("[ERROR] Currently only tables are supported in netmapMemory.createMemPool()")
		return nil
	end
	args = args[1]
	if not args.queue then
		print("[ERROR] When using Netmap, a ring needs to be given in the .queue argument")
		return nil
	end
	if args.n or args.socket or args.bufSize then
		print("[WARNING] You set variables intended for DPDK, they are ignored by netmap")
	end
	if args.queue.num_slots ~= args.queue.avail() then
		print("[ERROR] Packets left in the ring - probably not what you want")
		return nil
	end
	local mem = {}
	mem.queue = args.queue
	mem.mbufs = ffi.new("struct rte_mbuf[?]", args.queue.num_slots)
	for i=0,args.queue.num_slots do
		mem.mbufs[i].pkt.data = netmapc.NETMAP_BUF(mem.queue, i) 
		mem.mbufs[i].pkt.slot = netmapSlot(mem.queue, i) -- XXX do I need this?
		setmetatable(mem.mbufs[i], packet) -- XXX is this correct?
	end

	if args.func then
		for buf in mem.mbufs do
			args.func(buf)
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
	if n > self.queue.num_slots then
		print("[ERROR] not enough slots in the memory pool / ring - check your config")
		return nil
	end
	while self.queue:avail() < n do -- block / busy wait until array size is satisfied
		self.queue:sync()
	end
	return setmetatable({
		size = n,
		maxSize = n,
		array = 0, --TODO where will this be used afterall? (was there with DPDK)
		mem = self,
		first = self.queue.head 
		last = (self.queue.head + n) % self.queue.num_slots
	}, bufArray)
end

----------------------------------------------------------------------------------
---- Buffer Array
----------------------------------------------------------------------------------

local bufArray = {}
bufArray.__index = bufArray

--- Prepare the buffer array with the length of the packets
--- @param Length of the packets
function bufArray:alloc(len)
	-- no actual allocation, just update the the length fields
	-- wait until there is space in the ring
	local queue = self.mem.queue
	while queue:avail() < len do
		queue:sync()
	end
	self.first = queue.head
	self.last = self.first + self.size
	if self.last > queue.num_slots then
		self.last = self.last - queue.num_slots
	end
	for _, buf in ipairs(self) do
		buf.len = len -- XXX is this sufficient -> buf.data.data_len, buf.data.pkt_len
	end
end

function bufArray.__index(self, k)
	local num_slots = self.mem.queue.num_slots
	if not k < num_slots then
		k = k - num_slots
	end
	return type(k) == "number" and self.mem.mbufs[k - 1] or bufArray[k] -- no idea what that or does (copied from DPDK)
end

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




return mod

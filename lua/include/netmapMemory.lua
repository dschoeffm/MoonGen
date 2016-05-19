---------------------------------
--- @file memoryNetmap.lua
--- @brief High level memory management for Netmap
--- @todo feature level of DPDK
---------------------------------

local netmapc = require "netmapc"
local packet = require "packet"
local ffi = require "ffi"
local log = require "log"
local dpdkc = require "dpdkc"
local dpdk = require "dpdk"

local mod = {}

local mempool = {}
mempool.__index = mempool

local bufArray = {}

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
	mem.mbufs = {}
	mem.mbufsp = ffi.new("struct rte_mbuf*[?]", 2048)

	for i=0,args.queue.nmRing.num_slots -1 do
		mem.mbufs[i] = ffi.new("struct rte_mbuf")
		mem.mbufsp[i] = mem.mbufs[i]
		if mem.queue.tx then
			mem.queue.dev.c.nm_ring[mem.queue.id].mbufs_tx[i] = mem.mbufs[i]
		else
			mem.queue.dev.c.nm_ring[mem.queue.id].mbufs_rx[i] = mem.mbufs[i]
		end
		local buf_addr = netmapc.NETMAP_BUF_wrapper(mem.queue.nmRing, mem.queue.nmRing.slot[i].buf_idx)
		mem.mbufs[i].buf_addr = buf_addr
		mem.mbufs[i].buf_len = 1522
	end

	if args.func then
		for i=0,args.queue.nmRing.num_slots -1 do
			args.func(mem.mbufs[i])
		end
	end

	setmetatable(mem, mempool)

	log:debug("return from createMemPool")

	return mem
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

	local tx = 0 --saves time/branches later
	if self.queue.tx then
		tx = 1
	else
		tx = 0
	end

	local bufs = {
		size = n,
		maxSize = n,
		array = 0, --TODO where will this be used afterall? (was there with DPDK)
		mem = self,
		mbufs = self.mbufs,
		queue = self.queue,
		dev = self.queue.dev,
		numSlots = self.queue.nmRing.num_slots,
		first = self.queue.nmRing.head,
		ipv4 = false,
		tcp = false,
		tx = tx
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
	while queue:avail() < (self.maxSize + self.tx) do --first is context descriptor (on tx)
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

function bufArray:offloadUdpChecksums(ipv4, l2Len, l3Len)
	self.tcp = false
	ipv4 = ipv4 == nil or ipv4
	self.ipv4 = ipv4
	l2Len = l2Len or 14
	if ipv4 then
		l3Len = l3Len or 20
		local ol_flags = bit.bor(dpdk.PKT_TX_IPV4, dpdk.PKT_TX_IP_CKSUM, dpdk.PKT_TX_UDP_CKSUM)
		local tx_offload = l2Len + l3Len * 128
		netmapc.nm_calc_ipv4_pseudo_header_checksums(self.mem.mbufsp, self.size, 20, self.numSlots, self.first+1, ol_flags, tx_offload)
	else
		l3Len = l3Len or 40
		local ol_flags = bit.bor(dpdk.PKT_TX_IPV6, dpdk.PKT_TX_IP_CKSUM, dpdk.PKT_TX_UDP_CKSUM)
		local tx_offload = l2Len + l3Len * 128
		netmapc.nm_calc_ipv6_pseudo_header_checksums(self.mem.mbufsp, self.size, 30, self.numSlots, self.first+1, ol_flags, tx_offload)
	end
end

--- If called, IP chksum offloading will be done for the first n packets
--	in the bufArray.
--	@param ipv4 optional (default = true) specifies, if the buffers contain ipv4 packets
--	@param l2Len optional (default = 14)
--	@param l3Len optional (default = 20)
--	@param n optional (default = bufArray.size) for how many packets in the array, the operation
--	  should be applied
function bufArray:offloadIPChecksums(ipv4, l2Len, l3Len, n)
	-- please do not touch this function without carefully measuring the performance impact
	-- FIXME: touched this.
	--	added parameter n
	ipv4 = ipv4 == nil or ipv4
	self.ipv4 = ipv4
	l2Len = l2Len or 14
	n = n or self.size

	local ol_flags = 0
	local tx_offload = 0
	if ipv4 then
		l3Len = l3Len or 20
		ol_flags = bit.bor(dpdk.PKT_TX_IPV4, dpdk.PKT_TX_IP_CKSUM)
		tx_offload = l2Len + l3Len * 128
	else
		l3Len = l3Len or 40
		ol_flags = bit.bor(dpdk.PKT_TX_IPV6, dpdk.PKT_TX_IP_CKSUM)
		tx_offload = l2Len + l3Len * 128
	end
	netmapc.nm_set_offload_flags(self.mem.mbufsp, self.size, self.numSlots, self.first+1, ol_flags, tx_offload)
end

function bufArray:offloadTcpChecksums(ipv4, l2Len, l3Len)
	self.tcp = true
	ipv4 = ipv4 == nil or ipv4
	self.ipv4 = ipv4
	l2Len = l2Len or 14
	if ipv4 then
		l3Len = l3Len or 20
		local ol_flags = bit.bor(dpdk.PKT_TX_IPV4, dpdk.PKT_TX_IP_CKSUM, dpdk.PKT_TX_TCP_CKSUM)
		local tx_offload = l2Len + l3Len * 128
		netmapc.nm_calc_ipv4_pseudo_header_checksums(self.mem.mbufsp, self.size, 25, self.numSlots, self.first+1, ol_flags, tx_offload)
	else
		l3Len = l3Len or 40
		local ol_flags = bit.bor(dpdk.PKT_TX_IPV6, dpdk.PKT_TX_IP_CKSUM, dpdk.PKT_TX_TCP_CKSUM)
		local tx_offload = l2Len + l3Len * 128
		netmapc.nm_calc_ipv6_pseudo_header_checksums(self.mem.mbufsp, self.size, 35, self.numSlots, self.first+1, ol_flags, tx_offload)
	end
end

--- Offloads VLAN tags on all packets.
-- Equivalent to calling pkt:setVlan(vlan, pcp, cfi) on all packets.
--function bufArray:setVlans(vlan, pcp, cfi)
	--local tci = vlan + bit.lshift(pcp or 0, 13) + bit.lshift(cfi or 0, 12)
	--for i = 0, self.size - 1 do
	--	self.array[i].pkt.vlan_tci = tci
	--	self.array[i].ol_flags = bit.bor(self.array[i].ol_flags, dpdk.PKT_TX_VLAN_PKT)
	--end
--end


function bufArray.__index(self, k)
	if type(k) == "number" then
		if k + self.first + self.tx >= self.numSlots then
			k = k - self.numSlots +1
		end
		return self.mbufs[k + self.first +self.tx -1]
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
	local function it(tab, i)
		local self = tab.self
		if tab.count == self.size then
			return nil
		end
		tab.count = tab.count+1
		if i+1 >= self.numSlots then
			i = 0
		end
		--if self.mem.mbufs[i] == nil then
		--	log:fatal("bufArray for (iterator): self.mem.mbufs[" .. i .. "] == nil")
		--end
		return i + 1, self.mbufs[i]
	end

	function bufArray.__ipairs(self)
		return it, {self=self, count=0} , self.first+1
	end
end

function bufArray.__tostring(self)
	return ("first=" .. self.first .. " size=" .. self.size .. " maxSize=" .. self.maxSize)
end

return mod

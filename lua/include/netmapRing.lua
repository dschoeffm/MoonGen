local ffi = require "ffi"
local netmapc = require "netmapc"

local netmapRing = {}
netmapRing.__index = netmapRing

--- Returns a netmap ring object
--- @param desc: descriptor returned by netmap.netmapOpen
--- @param index: ringid
--- @param tx: true for tx ring, false for rx
--- @return A netmap ring/queue object
function netmapRing:create(desc, index, tx)
	local r
	local nifp = netmapc.NETMAP_IF(desc.mem, desc.nmr.nr_offset)
	if tx then
		r = netmapc.NETMAP_TXRING(nifp, index)
	else 
		r = netmapc.NETMAP_RXRING(nifp, index)
	end

	r.tx = tx
	r.fd = fd

	setmetatable(r, self)

	return r
end

--- Synchronizes the user view with the OS/HW view
function netmapRing:sync()
	if self.tx then
		netmapc.ioctl(self.fd, netmapc.NIOCTXSYNC)
		return
	else
		netmapc.ioctl(self.fd, netmapc.NIOCRXSYNC)
		return
	end
end

--- Dispatches the sending of a buffer array
--- @param bufs: buffer array to send
function netmapRing:send(bufs)
	self.head = bufs.last
	self.cur = self.head
	self.sync()
end

--- Returns how many slots are available in the ring
--- @return number of available buffers
function netmapRing:avail()
	ret = self.tail - self.cur
	if ret < 0 then
		ret = ret + ring.num_slots
	end
	return ret
	--return netmapc.nm_ring_space(self.c) -- original c call
end

---- Probably never used anyways
-- Returns the index of the next slot
--function netmapRing:nextSlot() -- never really used
--	return netmapc.nm_ring_next(self.c, self.pos); -- TODO translate to native Lua -> faster
--end

ffi.metatype("struct netmap_ring*", netmapRing) -- XXX needed? r in create is cdata already

return netmapRing

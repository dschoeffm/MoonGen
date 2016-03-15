local ffi = require "ffi"
local netmapc = require "netmapc"

local Netmap_ring = {}
Netmap_ring.__index = Netmap_ring

ffi.metatype("struct netmap_ring*", Netmap_ring)

-- Returns a netmap ring object
function NetmapRing:create(fd, nifp, index, tx)
	local r
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

-- Synchronizes the user view with the OS/HW view
function NetmapRing:sync()
	self.c.cur = self.pos
	self.c.head = self.pos
	if self.tx then
		netmapc.ioctl(self.fd, NIOCTXSYNC)
		return
	else
		netmapc.ioctl(self.fd, NIOCRXSYNC)
		return
	end
	print("NetmapRing:sync() tx should have been 1 or 0")
end

-- Retuns how many slots are available in the ring
function NetmapRing:avail()
	return netmapc.nm_ring_space(self.c)
end

-- Returns the index of the next slot
function NetmapRing:next_slot()
	return netmapc.nm_ring_next(self.c, self.pos); -- TODO translate to native Lua -> faster
end



return NetmapRing

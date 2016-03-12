local ffi = require "ffi"
local netmapc = require "netmapc"

local Netmap_ring = {}
Netmap_ring.__index = Netmap_ring

ffi.metatype("struct netmap_ring*", Netmap_ring)

-- Returns a netmap ring object
function Netmap_ring:create(fd, nifp, index, tx)
	local c
	if tx then
		c = netmapc.NETMAP_TXRING(nifp, index)
	else 
		c = netmapc.NETMAP_RXRING(nifp, index)
	end

	r = {}
	r.tx = tx
	r.fd = fd
	r.c = c
	r.pos = c.head
	c.cur = c.head

	setmetatable(r, self)

	return r
end

-- Synchronizes the user view with the OS/HW view
function Netmap_ring:sync()
	self.c.cur = self.pos
	self.c.head = self.pos
	if self.tx then
		netmapc.ioctl(self.fd, NIOCTXSYNC)
		return
	else
		netmapc.ioctl(self.fd, NIOCRXSYNC)
		return
	end
	print("Netmap_ring:sync() tx should have been 1 or 0")
end

-- Retuns how many slots are available in the ring
function Netmap_ring:avail()
	return netmapc.nm_ring_space(self.c)
end

-- Returns the index of the next slot
function Netmap_ring:next_slot()
	return netmapc.nm_ring_next(self.c, self.pos);
end

return Netmap_ring

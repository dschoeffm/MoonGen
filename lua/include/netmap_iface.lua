local ffi = require "ffi"
local netmapc = require "netmapc"
local Netmap_ring = require "netmap_ring"

local Netmap_iface = {}
Netmap_iface.__index = Netmap_iface

ffi.metatype("struct netmap_if*", Netmap_iface)

-- Returns a netmap ring object
function Netmap_iface:create(desc)
	r = {}
	setmetatable(r, self)
	r.c = netmapc.NETMAP_IF(desc.mem, desc.c.nr_offset)
	r.tx_rings = r.c.ni_tx_rings -- copy over should be faster accessible
	r.rx_rings = r.c.ni_rx_rings
	r.fd = desc.fd
	return r
end

-- Get a ring of the interface
function Netmap_iface:get_ring(index, tx)
	if tx and not index < self.tx_rings then
		print("Netmap_iface:get_ring() wrong index")
		return nil
	else if not tx and not index < self.rx_rings then 
		print("Netmap_iface:get_ring() wrong index")
		return nil
	end

	return Netmap_ring:create(self.fd, self.c, index, tx)
end

return Netmap_iface

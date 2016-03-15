local ffi = require "ffi"
local netmapc = require "netmapc"
local NetmapRing = require "netmap_ring"

local NetmapIface = {}
NetmapIface.__index = NetmapIface


-- Create Netmap Interface
-- @return Interface as object
function NetmapIface:create(desc)
	r = netmapc.NETMAP_IF(desc.mem, desc.nr_offset)
	setmetatable(r, self)
	r.fd = desc.fd
	return r
end

-- Get a ring of the interface
-- @return Ring as object
function NetmapIface:getRing(index, tx)
	if tx and not index < self.ni_tx_rings then
		print("Netmap_iface:get_ring() wrong index")
		return nil
	else if not tx and not index < self.ni_rx_rings then 
		print("Netmap_iface:get_ring() wrong index")
		return nil
	end

	return NetmapRing:create(self.fd, self, index, tx)
end

------------------------------------------------------------------------
---- Metatypes
------------------------------------------------------------------------

ffi.metatype("struct netmap_if", NetmapIface) -- XXX is this done by the cast already?

return NetmapIface

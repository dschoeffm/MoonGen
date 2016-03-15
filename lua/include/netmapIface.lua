local ffi = require "ffi"
local netmapc = require "netmapc"
local netmapRing = require "netmapRing"

local netmapIface = {}
netmapIface.__index = netmapIface


--- Create Netmap Interface
--- @param desc: descriptor given by the netmap open function
--- @return Interface as object
function netmapIface:create(desc)
	r = netmapc.NETMAP_IF(desc.mem, desc.nr_offset)
	setmetatable(r, self)
	r.fd = desc.fd
	return r
end

--- Get a ring of the interface
--- @param index: index of the ring inside the interface
--- @param tx: true for tx, false for rx
--- @return Ring as object
function netmapIface:getRing(index, tx)
	if tx and not index < self.ni_tx_rings then
		print("netmapIface:get_ring() wrong index")
		return nil
	else if not tx and not index < self.ni_rx_rings then 
		print("netmapIface:get_ring() wrong index")
		return nil
	end

	return netmapRing:create(self.fd, self, index, tx)
end

------------------------------------------------------------------------
---- Metatypes
------------------------------------------------------------------------

ffi.metatype("struct netmap_if*", netmapIface) -- XXX is this done by the cast already?

return netmapIface

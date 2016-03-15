local ffi = require "ffi"
local netmapc = require "netmapc"

local netmapSlot = {}
netmapSlot.__index = netmapSlot

--- Returns a netmap ring object
--- @param ring: a netmap ring
--- @param index: id of the slot
--- @return a netmap slot object
function netmapSlot:create(ring, index)
	setmetatable(r, self)
	r = ffi.cast("struct netmap_slot", ring.slot[index])
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

return netmapSlot

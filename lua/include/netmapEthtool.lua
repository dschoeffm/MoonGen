local ffi = require "ffi"

local mod = {}

function mod.setRingCount(port, count)
	local handle = io.popen(("ethtool -L %s combined %d"):format(port, count))
	handle:read() -- wait for it to return
	handle:close()
end

function mod.setRingSize(port, size)
	local handle = io.popen(("ethtool -G %s tx %d rx %d"):format(port, size, size))
	handle:read()
	handle:close()
end

function mod.setLinkUp(port)
	local handle = io.popen(("ip l set %s up"):format(port))
	handle:read()
	handle:close()
end

function mod.isLinkUp(port)
	local handle = io.popen(("ip l show %s"):format(port))
	local line = handle:read()
	handle:close()
	if line:find(",UP,") == nil then
		return false
	else
		return true
	end
end

function mod.waitForLink(port)
	ffi.cdef[[int sleep(int sec);]]
	while not mod.isLinkUp(port) do
		ffi.C.sleep(1)
	end
end

return mod

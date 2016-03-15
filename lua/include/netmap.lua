local netmapc = require "netmapc"
local ffi = require "ffi"

local mmaped = false
local mem

local function check_rings_slots(config, nmr)
	if config.nr_tx_rings ~= nmr.nr_tx_rings then
		return -1 end
	if config.nr_rx_rings ~= nmr.nr_rx_rings then
		return -1 end
	if config.nr_tx_slots ~= nmr.nr_tx_slots then
		return -1 end
	if config.nr_rx_slots ~= nmr.nr_rx_slots then
		return -1 end
	return 0
end

local function print_nmr(nmr)
	print("nmreq values:")
	print("nr_name: " .. nmr.nr_name)
	print("nr_version: " .. nmr.nr_version)
	print("nr_offset: " .. nmr.nr_offset)
	print("nr_memsize: " .. nmr.nr_memsize)
	print("nr_tx_slots: " .. nmr.nr_tx_slots)
	print("nr_rx_slots: " .. nmr.nr_rx_slots)
	print("nr_tx_rings: " .. nmr.nr_tx_rings)
	print("nr_rx_rings: " .. nmr.nr_rx_rings)
	print("nr_ringid: " .. nmr.nr_ringid)
	print("nr_cmd: " .. nmr.nr_cmd)
	print("nr_arg1: " .. nmr.arg1)
	print("nr_arg2: " .. nmr.arg2)
	print("nr_arg3: " .. nmr.arg3)
	print("nr_flags: " .. nmr.flags)
end

--- Opens the netmap device
--- @param iface: which interface to use (e.g. eth0)
--- @param ringid: number of the ring
--- @return Descriptor used by other functions
function mod.netmapOpen(iface, ringid)
	-- open the netmap control file
	local fd = netmapc.open("/dev/netmap", O_RDWR)
	if fd == -1 then
		print("Error opening /dev/netmap")
		return nil
	end

	desc = {}
	desc.fd = fd

	-- create request and populate it from the config
	local nmr = ffi.new("struct nmreq")
	desc.nmr = nmr
	nmr.nr_name = iface
	nmr.nr_version = NETMAP_API
	nmr.nr_flags = NR_REG_ONE_NIC
	nmr.nr_ringid = ringid
	-- not reliably supported anyways
	--nmr.nr_tx_rings = config.nr_tx_rings
	--nmr.nr_rx_rings = config.nr_rx_rings
	--nmr.nr_tx_slots = config.nr_tx_slots
	--nmr.nr_rx_slots = config.nr_rx_slots

	-- do ioctl to register the device
	local ret = ioctl(fd, NIOCREGIF, nmr)
	if ret == -1 then:
		print("Error issuing NIOCREGIF")
		return nil
	end

	-- mmap if not happend before
	if not mmaped then
		mem = netmapc.mmap(0, nmr.nr_memsize, PROT_READ_WRITE, MAP_SHARED, fd, 0);
		mmaped = true
	end

	desc.mem = mem

	-- finally return the descriptor
	return desc
end

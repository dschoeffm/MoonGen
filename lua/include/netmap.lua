local netmapc = require "netmapc"
local ffi = require "ffi"

local mmaped = {}

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

-- iface: which interface to use (e.g. eth0)
-- ringid: number of the ring
-- tx: 1 if ring is tx, 0 is rx
function netmap_open(config, ringid, tx)
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
	nmr.nr_name = config.iface
	nmr.nr_version = NETMAP_API
	nmr.nr_flags = NR_REG_ONE_NIC
	nmr.nr_ringid = ringid
	nmr.nr_tx_rings = config.nr_tx_rings
	nmr.nr_rx_rings = config.nr_rx_rings
	nmr.nr_tx_slots = config.nr_tx_slots
	nmr.nr_rx_slots = config.nr_rx_slots

	-- do ioctl to register the device
	local ret = ioctl(fd, NIOCREGIF, nmr)
	if ret == -1 then:
		print("Error issuing NIOCREGIF")
		return nil
	end

	-- check if we got as much rings as slots as we expected
	if check_rings_slots(config, nmr) == -1 then
		print("Please adjust config")
		print_nmr(nmr)
		return nil
	end

	-- check if we need to mmap do so if needed
	if mmaped[config.iface] == nil then:
		local mem = netmapc.mmap(0, nmr.nr_memsize, PROT_READ_WRITE, MAP_SHARED, fd, 0);
		mmaped[fd] = mem
	end

	-- finally return the descriptor
	return desc
end

function txsync(fd)
	netmapc.ioctl(fd, NIOCTXSYNC)
end

function rxsync(fd)
	netmapc.ioctl(fd, NIOCRXSYNC)
end

-- TODO blocking poll stuff

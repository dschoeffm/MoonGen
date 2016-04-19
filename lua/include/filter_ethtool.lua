---------------------------------
--- @file filter_ethtool.lua
--- @brief Filter for netmap/ethtool ...
--- @todo TODO docu
---------------------------------

local mod = {}

local ffi = require "ffi"
local dpdk = require "dpdk"
local err = require "error"
local log = require "log"

--[[ Not supported at this point
function mod.l2Filter(dev, etype, queue)
	if queue == -1 then
		queue = 127
	end
	dpdkc.write_reg32(dev.id, ETQF[1], bit.bor(ETQF_FILTER_ENABLE, etype))
	dpdkc.write_reg32(dev.id, ETQS[1], bit.bor(ETQS_QUEUE_ENABLE, bit.lshift(queue, ETQS_RX_QUEUE_OFFS)))
end
--]]

--- Installs a 5tuple filter on the device.
---  Matching packets will be redirected into the specified rx queue
--- @param filter A table describing the filter. Possible fields are
---   src_ip    :  Source IPv4 Address
---   dst_ip    :  Destination IPv4 Address
---   src_port  :  Source L4 port
---   dst_port  :  Destination L4 port
---   l4protocol:  L4 Protocol type
---                supported protocols: ip.PROTO_ICMP, ip.PROTO_TCP, ip.PROTO_UDP
---                If a non supported type is given, the filter will only match on
---                protocols, which are not supported.
---  All fields are optional.
---  If a field is not present, or nil, the filter will ignore this field when
---  checking for a match.
--- @param queue RX Queue, where packets, matching this filter will be redirected
--- @param priority optional (default = 1) The priority of this filter rule.
---  7 is the highest priority and 1 the lowest priority.
function mod.addHW5tupleFilter(dev, filter, queue, priority)
	-- tested:
	-- ethtool -K eth11 ntuple on
	-- ethtool -U eth11 flow-type udp4 src-ip 10.0.128.23 action 2
	--
	local handle = io.popen("ethtool -K eth11 ntuple on")
	handle:read()
	handle:close()

	local cmd = "ethtool -U " .. queue.dev.port ..  " flow-type "
	if filter.l4protocol == 0x01 then
		cmd = cmd .. " ip4 l4proto 1"
	elseif filter.l4protocol == 0x06 then
		cmd = cmd .. " tcp4"
	elseif filter.l4protocol == 0x11 then
		cmd = cmd .. " udp4"
	else
		log:fatal("filter_ethtool.addHW5tupleFilter() unsupported layer 4 protocol used")
	end
	if filter.src_ip then
		cmd = cmd .. " src-ip " .. filter.src_ip
	end
	if filter.dst_ip then
		cmd = cmd .. " dst-ip " .. filter.dst_ip
	end
	if filter.src_port then
		cmd = cmd .. " src-port " .. filter.src_port
	end
	if filter.dst_port then
		cmd = cmd .. " dst-port " .. filter.dst_port
	end

	cmd = cmd .. " action " .. queue.id

	handle = io.popen(cmd)
	handle:read()
	handle:close()
end

return mod

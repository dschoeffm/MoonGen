---------------------------------
--- @file filter_ethtool.lua
--- @brief Filter for netmap/ethtool ...
--- @todo TODO docu
---------------------------------

local mod = {}

local netmapDevice = require "netmapDevice"
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
---   src_ip    :  Sourche IPv4 Address
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
	local cmd = "ethtool -U flow-type "
	if filter.l4protocol == ip.PROTO_ICMP then
		cmd = cmd .. " ip4 l4proto 1"
	else if filter.l4protocol == ip.PROTO_TCP then
		cmd = cmd .. " tcp4"
	else if filter.l4protocol == ip.PROTO_UDP then
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
		cmd = cmd .. " dst-port " .. filter.dst-port
	end
	if filter.l4protocol then
		cmd = cmd .. " l4proto " .. filter.l4protocol
	end

	local handle = io.popen(cmd)
	-- TODO pick up here TODO
	--
	--
	--
	--[[ ixgbe_code
  local sfilter = ffi.new("struct rte_5tuple_filter")
  sfilter.src_ip_mask   = (filter.src_ip      == nil) and 1 or 0
  sfilter.dst_ip_mask   = (filter.dst_ip      == nil) and 1 or 0
  sfilter.src_port_mask = (filter.src_port    == nil) and 1 or 0
  sfilter.dst_port_mask = (filter.dst_port    == nil) and 1 or 0
  sfilter.protocol_mask = (filter.l4protocol  == nil) and 1 or 0

  sfilter.priority = priority or 1
  if(sfilter.priority > 7 or sfilter.priority < 1) then
    log:fatal("Filter priority has to be a number from 1 to 7")
    return
  end

  sfilter.src_ip    = filter.src_ip     or 0
  sfilter.dst_ip    = filter.dst_ip     or 0
  sfilter.src_port  = filter.src_port   or 0
  sfilter.dst_port  = filter.dst_port   or 0
  sfilter.protocol  = filter.l4protocol or 0
  --if (filter.l4protocol) then
  --  print "[WARNING] Protocol filter not yet fully implemented and tested"
  --end

  if dev.filters5Tuple == nil then
    dev.filters5Tuple = {}
    dev.filters5Tuple.n = 0
  end
  dev.filters5Tuple[dev.filters5Tuple.n] = sfilter
  local idx = dev.filters5Tuple.n
  dev.filters5Tuple.n = dev.filters5Tuple.n + 1

  local state
  if (dev:getPciId() == device.PCI_ID_X540) then
    -- TODO: write a proper patch for dpdk
    state = ffi.C.mg_5tuple_add_HWfilter_ixgbe(dev.id, idx, sfilter, queue.qid)
  else
    state = ffi.C.rte_eth_dev_add_5tuple_filter(dev.id, idx, sfilter, queue.qid)
  end

  if (state ~= 0) then
    log:fatal("Filter not successfully added: %s", err.getstr(-state))
  end

  return idx
  --]]
end

return mod

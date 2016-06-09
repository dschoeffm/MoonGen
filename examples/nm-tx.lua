local dpdk		= require "dpdk"
local nmMemory	= require "netmapMemory"
local nmDevice	= require "netmapDevice"
local stats		= require "stats"
local log 		= require "log"
local ffi = require "ffi"
local p = require "profiler"

function master(txPort, txBufS)
	--log.level = 0
	if (not txPort) or (not txBufS) then
		log:info("usage: txPort txBufS")
		return
	end

	local txDev = nmDevice.config({ port = txPort })

	dpdk.launchLua("loadSlave", txDev:getTxQueue(0), txBufS)

	ffi.cdef[[unsigned int sleep(unsigned int seconds);]]
	ffi.C.sleep(20)
	dpdk.stop()

	dpdk.waitForSlaves()
end

function loadSlave(queue, txBufS)
	log:info("loadSlave started")

	local packetLen = 60

	memPoolArgs = {}
	memPoolArgs.queue = queue -- XXX not needed in DPDK
	memPoolArgs.func = function(buf)
		buf:getUdpPacket(ipv4):fill{
			ethDst="90:e2:ba:92:db:fc", ethSrc="90:e2:ba:7e:9f:6c",
			ip4Dst="192.168.1.1", ip4Src="192.168.0.1",
			pktLength=packetLen }
		end
	local mem = nmMemory.createMemPool(memPoolArgs)

	local bufs = mem:bufArray(txBufS)
	local counter = 0
	local c = 0

	local txCtr = stats:newPktTxCounter("loadSlave", "plain")

	while dpdk.running() do
		-- fill packets and set their size 
		bufs:alloc(packetLen)
		for i, buf in ipairs(bufs) do
			if buf == nil then
				log:fatal("buffer " .. i .." was nil")
			end
			local pkt = buf:getUdpPacket(ipv4)
			
			--increment IP
			pkt.ip4.src:add(counter)
			counter = incAndWrap(counter, 100)

			txCtr:countPacket(buf)
		end
		--offload checksums to NIC
		--bufs:offloadIPChecksums(ipv4)
		--bufs:offloadUdpChecksums(ipv4)
		txCtr:update()
		queue:send(bufs)
	end
	txCtr:finalize()
end

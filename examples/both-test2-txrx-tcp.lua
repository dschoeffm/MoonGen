local dpdk		= require "dpdk"
local nmMemory	= require "netmapMemory"
local nmDevice	= require "netmapDevice"
local dpdkMemory	= require "memory"
local dpdkDevice	= require "device"
local stats		= require "stats"
local log 		= require "log"
local ffi = require "ffi"
local p = require "profiler"

function master(txPort, rxPort, txBufS)
	--log.level = 0
	if (not txPort) or (not rxPort) or (not txBufS) then
		log:info("usage: txPort rxPort txBufS")
		return
	end

	local txDev = nmDevice.config({ port = txPort })
	local rxDev = dpdkDevice.config({ port = rxPort })

	dpdk.launchLua("loadSlave", txDev:getTxQueue(0), txBufS)
	dpdk.launchLua("counterSlave", rxDev:getRxQueue(0))

	ffi.cdef[[unsigned int sleep(unsigned int seconds);]]
	ffi.C.sleep(20)
	dpdk.stop()

	dpdk.waitForSlaves()
end

function loadSlave(queue, txBufS)
	--wait for the rx slave to be initialized for sure
	ffi.cdef[[int sleep(int sec);]]
	ffi.C.sleep(3)

	log:info("loadSlave started")

	log.level = 0

	-- min TCP packet size for IPv6 is 74 bytes (+ CRC)
	local packetLen = 60

	memPoolArgs = {}
	memPoolArgs.queue = queue -- XXX not needed in DPDK
	memPoolArgs.func = function(buf)
		buf:getTcpPacket(ipv4):fill{
			--ethSrc="90:e2:ba:2c:cb:02", ethDst="90:e2:ba:35:b5:81",
			ethDst="A0:36:9F:3B:71:DA", ethSrc=queue,
			ip4Dst="192.168.1.1", ip4Src="192.168.0.1",
			pktLength=packetLen }
		end
	local mem = nmMemory.createMemPool(memPoolArgs)

	local bufs = mem:bufArray(txBufS)
	local counter = 0
	local c = 0

	p.start()
	while dpdk.running() do
	--for j=0,3 do
		-- fill packets and set their size 
		bufs:alloc(packetLen)
		for i, buf in ipairs(bufs) do
		--for i=1,bufs.size do
			--local buf = bufs[i]
			
			--log:debug("i=" .. i)
			if buf == nil then
				log:fatal("buffer " .. i .." was nil")
			end
			local pkt = buf:getTcpPacket(ipv4)
			
			--increment IP
			pkt.ip4.src:add(counter)
			counter = incAndWrap(counter, 100)

			-- dump first 3 packets
			if c < 3 then
				buf:dump()
				c = c + 1
			end
			--log:debug("i=" .. i)
		end
		--log:debug("before offloading")
		--offload checksums to NIC
		bufs:offloadIPChecksums(ipv4)
		bufs:offloadTcpChecksums(ipv4)
		--log:debug("after offloading")
	
		--log:info("sending bufArray")
		queue:send(bufs)
		--log:debug("after sending")
	end
	p.stop()
end

function counterSlave(queue)
	log.level = 0
	local bufs = dpdkMemory.bufArray() -- DPDK
	--local bufs = queue:bufArray() -- Netmap
	local rxCtr = stats:newPktRxCounter("counterSlave", "plain")
	local c = 0
	while dpdk.running() do
		local rx = queue:recv(bufs)
		for i = 1, rx do
			local buf = bufs[i]
			local pkt = buf:getTcpPacket()
			rxCtr:countPacket(buf)

			-- dump first 3 packets
			if c < 3 then
				buf:dump()
				c = c + 1
			end
		end
		-- update() on rxPktCounters must be called to print statistics periodically
		-- this is not done in countPacket() for performance reasons (needs to check timestamps)
		rxCtr:update()
		bufs:freeAll()
	end

	ffi.cdef[[unsigned int sleep(unsigned int seconds);]]
	ffi.C.sleep(1)

	rxCtr:finalize()
	-- TODO: check the queue's overflow counter to detect lost packets
end

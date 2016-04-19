local dpdk		= require "dpdk"
local nmMemory	= require "netmapMemory"
local nmDevice	= require "netmapDevice"
local dpdkMemory	= require "memory"
local dpdkDevice	= require "device"
local stats		= require "stats"
local log 		= require "log"
local ffi = require "ffi"
local p = require "profiler"

function master(txPort, rxPort, rxCount)
	--log.level = 0
	if (not txPort) or (not rxPort) or (not rxCount) then
		log:info("usage: txPort rxPort rxCount")
		return
	end

	txPort = tonumber(txPort)
	local txDev = dpdkDevice.config({ port = txPort, rxQueues = rxCount })
	local rxDev = nmDevice.config({ port = rxPort })

	dpdk.launchLua("loadSlave", txDev:getTxQueue(0))
	for i=0,rxCount-1 do
		dpdk.launchLua("counterSlave", rxDev:getRxQueue(i))
	end

	ffi.cdef[[unsigned int sleep(unsigned int seconds);]]
	ffi.C.sleep(20)
	dpdk.stop()

	dpdk.waitForSlaves()
end

function loadSlave(queue)
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
		buf:getUdpPacket(ipv4):fill{
			--ethSrc="90:e2:ba:2c:cb:02", ethDst="90:e2:ba:35:b5:81",
			ethSrc="A0:36:9F:3B:71:DA", ethDst="a0:36:9f:3b:71:d8",
			ip4Dst="192.168.1.1", ip4Src="192.168.0.1",
			pktLength=packetLen }
		end
	local mem = dpdkMemory.createMemPool(memPoolArgs)

	local bufs = mem:bufArray(128)
	local counter = 0
	local c = 0

	local txCtr = stats:newDevTxCounter(queue, "plain")

	while dpdk.running() do
	--for j=0,3 do
		-- fill packets and set their size
		bufs:alloc(packetLen)
		for i, buf in ipairs(bufs) do
			if buf == nil then
				log:fatal("buffer was nil")
			end
			local pkt = buf:getUdpPacket(ipv4)
			
			--increment IP
			pkt.ip4.src:add(counter)
			counter = incAndWrap(counter, 100)

			-- dump first 3 packets
			--if c < 3 then
			--	buf:dump()
			--	c = c + 1
			--end
			--txCtr:countPacket(buf)
		end
		--offload checksums to NIC
		bufs:offloadTcpChecksums(ipv4)
		txCtr:update()
		queue:send(bufs)
	end

	ffi.cdef[[unsigned int sleep(unsigned int seconds);]]
	ffi.C.sleep(1) -- let counter write output first

	txCtr:finalize()
	log:info("loadSlave exits")
end

function counterSlave(queue)
	log:info("counterSlave started")
	log.level = 0
	--local bufs = dpdkMemory.bufArray() -- DPDK
	local bufs = queue:bufArray(256) -- Netmap
	local rxCtr = stats:newPktRxCounter("counterSlave", "plain")
	p.start()
	while dpdk.running() do
		local rx = queue:recv(bufs)
		for i = 1, rx do
			local buf = bufs[i]
			rxCtr:countPacket(buf)
		end
		-- update() on rxPktCounters must be called to print statistics periodically
		-- this is not done in countPacket() for performance reasons (needs to check timestamps)
		rxCtr:update()
		bufs:freeAll()
	end
	p.stop()
	rxCtr:finalize()
	log:info("counterSlave exits")
	-- TODO: check the queue's overflow counter to detect lost packets
end

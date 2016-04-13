local dpdk		= require "dpdk"
local nmMemory	= require "netmapMemory"
local nmDevice	= require "netmapDevice"
local dpdkMemory	= require "memory"
local dpdkDevice	= require "device"
local stats		= require "stats"
local log 		= require "log"
local ffi = require "ffi"
local p = require "profiler"

function master(driver, fut)
	--log.level = 0
	if (not driver) or (not fut) then
		log:info("usage: driver FuT")
		return
	end

	driver = tonumber(driver)
	local driverDev = dpdkDevice.config({ port = driver })
	local futDev = nmDevice.config({ port = fut })

	dpdk.launchLua("loadSlave", driverDev:getTxQueue(0))
	dpdk.launchLua("counterSlave", driverDev:getRxQueue(0))
	dpdk.launchLua("futSlave", futDev:getTxQueue(0), futDev:getRxQueue(0))

	ffi.cdef[[unsigned int sleep(unsigned int seconds);]]
	ffi.C.sleep(20)
	dpdk.stop()

	dpdk.waitForSlaves()
end

function futSlave(tx, rx)
	log:info("counterSlave started")
	log.level = 0
	local bufs = rx:bufArray() -- Netmap
	local rxCtr = stats:newPktRxCounter("futSlave", "plain")
	p.start()
	while dpdk.running() do
		local rx = rx:recv(bufs)
		log:info("1")
		for i = 1, rx do
			local buf = bufs[i]
			log:info("packet: " .. i .. ", rx: " .. rx .. ", pointer: " .. buf.data)
			local pkt = buf:getUdpPacket(ipv4)
			log:info("2")
			pkt.eth:setSrcString("a0:36:9f:3b:71:d8")
			log:info("3")
			pkt.eth:setDstString("A0:36:9F:3B:71:DA")
			rxCtr:countPacket(buf)
			log:info("4")
		end
		rxCtr:update()
		tx:send(bufs)
	end
	p.stop()
	rxCtr:finalize()
	log:info("counterSlave exits")
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

	local txCtr = stats:newPktTxCounter(queue, "plain")

	while dpdk.running() do
		bufs:alloc(packetLen)
		for i, buf in ipairs(bufs) do
			local pkt = buf:getUdpPacket(ipv4)
			
			--increment IP
			pkt.ip4.src:add(counter)
			counter = incAndWrap(counter, 100)
			txCtr:countPacket(buf)
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
	local bufs = dpdkMemory.bufArray() -- DPDK
	local rxCtr = stats:newPktRxCounter("counterSlave", "plain")
	while dpdk.running() do
		local rx = queue:recv(bufs)
		for i = 1, rx do
			local buf = bufs[i]
			rxCtr:countPacket(buf)
		end
		rxCtr:update()
		bufs:freeAll()
	end
	rxCtr:finalize()
	log:info("counterSlave exits")
end

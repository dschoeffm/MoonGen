--local dpdk		= require "dpdk"
local memory	= require "netmapMemory"
local device	= require "netmapDevice"
--local stats		= require "stats"
local log 		= require "log"
local ffi = require "ffi"

function master(txPorts, minIp, numIps, rate)
	if not txPorts then
		log:info("usage: txPort1[,txPort2[,...]] [minIP numIPs rate]")
		return
	end
	txPorts = tostring(txPorts)
	minIp = minIp or "10.0.0.1"
	numIps = numIps or 100
	rate = rate or 0
	currentTxPort = txPorts  -- lets assume only one port
		--currentTxPort = tonumber(currentTxPort)
		log:info("before device.config")
		local txDev = device.config({ port = currentTxPort })
		log:info("before txDev:wait()")
		txDev:wait()
		log:info("before txDev:get:TXQueue(0):setRate(rate)")
		txDev:getTxQueue(0):setRate(rate)
		log:info("before dpdk.launchLua()")
		dpdk.launchLua("loadSlave", currentTxPort, 0, minIp, numIps)

	--dpdk.waitForSlaves()
	ffi.cdef[[unsigned int sleep(unsigned int seconds);]]
	ffi.C.sleep(20)
end

function loadSlave(port, queue, minA, numIPs)
	--- parse and check ip addresses
	log:info("started slave on port: " .. port .. " queue: " .. queue)
	local minIP, ipv4 = parseIPAddress(minA)
	if minIP then
		log:info("Detected an %s address.", minIP and "IPv4" or "IPv6")
	else
		log:fatal("Invalid minIP: %s", minA)
	end

	-- min TCP packet size for IPv6 is 74 bytes (+ CRC)
	local packetLen = ipv4 and 60 or 74
	
	-- continue normally
	local queue = device.get(port):getTxQueue(queue)
	local mem = memory.createMemPool(function(buf)
		buf:getTcpPacket(ipv4):fill{ 
			ethSrc="90:e2:ba:2c:cb:02", ethDst="90:e2:ba:35:b5:81", 
			ip4Dst="192.168.1.1", 
			ip6Dst="fd06::1",
			tcpSyn=1,
			tcpSeqNumber=1,
			tcpWindow=10,
			pktLength=packetLen }
	end)

	local bufs = mem:bufArray(128)
	local counter = 0
	local c = 0

	--local txStats = stats:newDevTxCounter(queue, "plain")
	while true do
		-- fill packets and set their size 
		bufs:alloc(packetLen)
		for i, buf in ipairs(bufs) do 			
			local pkt = buf:getTcpPacket(ipv4)
			
			--increment IP
			if ipv4 then
				pkt.ip4.src:set(minIP)
				pkt.ip4.src:add(counter)
			else
				pkt.ip6.src:set(minIP)
				pkt.ip6.src:add(counter)
			end
			counter = incAndWrap(counter, numIPs)

			-- dump first 3 packets
			if c < 3 then
				buf:dump()
				c = c + 1
			end
		end 
		--offload checksums to NIC
		bufs:offloadTcpChecksums(ipv4)
		
		queue:send(bufs)
	--	txStats:update()
	end
	--txStats:finalize()
end

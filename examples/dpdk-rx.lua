local dpdk		= require "dpdk"
local dpdkMemory	= require "memory"
local dpdkDevice	= require "device"
local stats		= require "stats"
local log 		= require "log"
local ffi = require "ffi"
local p = require "profiler"

function master(rxPort, rxBufS)
	--log.level = 0
	if (not rxPort) or (not rxBufS) then
		log:info("usage: txPort rxPort rxBufS")
		return
	end

	rxPort = tonumber(rxPort)

	local rxDev = dpdkDevice.config({ port = rxPort })

	dpdk.launchLua("counterSlave", rxDev:getRxQueue(0), rxBufS)

	ffi.cdef[[unsigned int sleep(unsigned int seconds);]]
	ffi.C.sleep(20)
	dpdk.stop()

	dpdk.waitForSlaves()
end

function counterSlave(queue, rxBufS)
	log:info("counterSlave started")
	log.level = 0
	local bufs = dpdkMemory.bufArray() -- DPDK
	--local bufs = queue:bufArray(rxBufS) -- Netmap
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

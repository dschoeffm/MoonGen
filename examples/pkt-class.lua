--- Replay a pcap file.

local mg      = require "moongen"
local device  = require "device"
local memory  = require "memory"
local stats   = require "stats"
local log     = require "log"
local pcap    = require "pcap"
local limiter = require "software-ratecontrol"
local pktClass = require "pktClass"

function configure(parser)
	parser:argument("dev1", "Device to use for replay."):args(1):convert(tonumber)
	parser:argument("dev2", "Device to use for classification."):args(1):convert(tonumber)
	parser:argument("file", "File to replay."):args(1)
	parser:argument("algo", "Classification algorithm."):args(1)
--	parser:option("-r --rate-multiplier", "Speed up or slow down replay, 1 = use intervals from file, default = replay as fast as possible"):default(0):convert(tonumber):target("rateMultiplier")
	parser:flag("-l --loop", "Repeat pcap file.")
	local args = parser:parse()
	return args
end

function master(args)
	local devSend = device.config{port = args.dev1}
	local devRecv = device.config{port = args.dev2}
	device.waitForLinks()
--	local rateLimiter
--	if args.rateMultiplier > 0 then
--		rateLimiter = limiter:new(dev:getTxQueue(0), "custom")
--	end
	mg.startTask("replay", dev1:getTxQueue(0), args.file, args.loop)
	mg.startTask("pktClassSlave", dev2:getRxQueue(0), args.algo)

	stats.startStatsTask{txDevices = {dev}}
	mg.waitForTasks()
end

function replay(queue, file, loop, rateLimiter, multiplier)
	local mempool = memory:createMemPool(4096)
	local bufs = mempool:bufArray()
	local pcapFile = pcap:newReader(file)
	local prev = 0
	local linkSpeed = queue.dev:getLinkStatus().speed
	while mg.running() do
		local n = pcapFile:read(bufs)
		if n > 0 then
			if rateLimiter ~= nil then
				if prev == 0 then
					prev = bufs.array[0].udata64
				end
				for i, buf in ipairs(bufs) do
					-- ts is in microseconds
					local ts = buf.udata64
					if prev > ts then
						ts = prev
					end
					local delay = ts - prev
					delay = tonumber(delay * 10^3) / multiplier -- nanoseconds
					delay = delay / (8000 / linkSpeed) -- delay in bytes
					buf:setDelay(delay)
					prev = ts
				end
			end
		else
			if loop then
				pcapFile:reset()
			else
				break
			end
		end
		if rateLimiter then
			rateLimiter:sendN(bufs, n)
		else
			queue:sendN(bufs, n)
		end
	end
end

function pktClassSlave(queue, algo)
	local bufs = memory.bufArray()
	local pktCtr = stats:newPktRxCounter("Packets counted", "plain")
	local classifier = pktClass.algo
	while mg.running() do
		local rx = queue:tryRecv(bufs, 63)
		for i = 1, rx do
			local buf = bufs[i]
			pktCtr:countPacket(buf)
		end
		classifier:run(bufs.array, rx)
		bufs:free(rx)
		pktCtr:update()
	end
	pktCtr:finalize()
end

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
	parser:flag("-l --loop", "Repeat pcap file.")
	local args = parser:parse()
	return args
end

function master(args)
	local devSend = device.config{port = args.dev1}
	local devRecv = device.config{port = args.dev2}
	device.waitForLinks()
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
		if n <= 0 then
			if loop then
				pcapFile:reset()
			end
		end
		queue:sendN(bufs, n)
	end
end

function pktClassSlave(queue, algo)
	local bufs = memory.bufArray()
	local pktCtr = stats:newPktRxCounter("Packets counted", "plain")
	local classifier = pktClass[algo]
	while mg.running() do
		local rx = queue:tryRecv(bufs, 63)
		for i = 1, rx do
			local buf = bufs[i]
			pktCtr:countPacket(buf)
		end
		classifier(bufs.array, rx)
		bufs:free(rx)
		pktCtr:update()
	end
	pktCtr:finalize()
end


local profile = require("jit.profile")
local log = require("log")

mod = {}
local dumps = {}
local started = false

local function cb(thread, samples, vmstate)
	dumps[#dumps+1] = { d = profile.dumpstack(thread, "F l\n         ", 3), s = vmstate}
end

function mod.start()
	if not started then
		profile.start("l", cb)
	end
end

function mod.stop()
	profile.stop()
	local acc = {}
	local states = {}
	states["N"] = 0; states["I"] = 0; states["C"] = 0; states["G"] = 0; states["J"] = 0; 
	for i=1,#dumps do
		states[dumps[i].s] = states[dumps[i].s] + 1
		if acc[dumps[i].d] == nil then
			local pos = #acc+1
			acc[pos] = {d = dumps[i].d, n = 1}
			acc[dumps[i].d] = pos
		else
			local pos = acc[dumps[i].d]
			acc[pos].n = acc[pos].n +1
		end
	end
	--[[ sort the other way round
	for i=1,#acc do
		local max = 0
		local maxPos = 0
		for k, v in ipairs(acc) do
			if v.n > max then
				max = v.n
				maxPos = k
			end
		end
		log:info(("%d: %s"):format(acc[maxPos].n, acc[maxPos].d))
		acc[maxPos].n = 0
	end
	--]]
	for i=1,#acc do
		local minPos = 0
		local min = math.huge
		for k, v in ipairs(acc) do
			if v.n < min then
				min = v.n
				minPos = k
			end
		end
		local percent = math.floor((acc[minPos].n / #dumps)*100)
		if percent > 4 then
			log:info(("%d percent : %s"):format(percent, acc[minPos].d))
		end
		acc[minPos].n = math.huge
	end
	log:info("Total number of dumps: " .. #dumps .. "\n")
	log:info("Native / Jitted : " .. math.floor((states["N"] / #dumps)*100))
	log:info("Interpreted     : " .. math.floor((states["I"] / #dumps)*100))
	log:info("C Code          : " .. math.floor((states["C"] / #dumps)*100))
	log:info("Garbage Collect.: " .. math.floor((states["G"] / #dumps)*100))
	log:info("JIT Compiler    : " .. math.floor((states["J"] / #dumps)*100))
end

return mod

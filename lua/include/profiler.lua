
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

local function percent(num, total)
	total = total or #dumps
	return (math.floor((num / total)*1000)) / 10
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

	for i=1,#acc do
		local minPos = 0
		local min = math.huge
		for k, v in ipairs(acc) do
			if v.n < min then
				min = v.n
				minPos = k
			end
		end
		--local percent = math.floor((acc[minPos].n / #dumps)*100)
		if percent(acc[minPos].n) > 4 then
			log:info(percent(acc[minPos].n) .. " percent : " .. acc[minPos].d)
		end
		acc[minPos].n = math.huge
	end

	log:info("Total number of dumps: " .. #dumps .. "\n")
	log:info("Native / Jitted : " .. percent(states["N"]))
	log:info("Interpreted     : " .. percent(states["I"]))
	log:info("C Code          : " .. percent(states["C"]))
	log:info("Garbage Collect.: " .. percent(states["G"]))
	log:info("JIT Compiler    : " .. percent(states["J"]))
end

return mod

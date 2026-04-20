--[[
This file is part of Plume🪶

Copyright © Erwan Barbedor
Licensed under the MIT License — see LICENSE for details.
]]

return function(plume)
	local opsNames = plume.debug.invTable(plume.ops)
	function plume.getOpcodeUsageReport()
		if not plume.runStatFlag then
			return "Turn on plume.runStatFlag to gather statistics about opcode usages."
		end
		local stats = {}
		local total = 0
		for k, v in pairs(plume.stats.opseq) do
			local ops = {}
			local zero = false
			for i=1, plume.runStatDeep do
				ops[plume.runStatDeep-i+1] = k%128
				k = math.floor(k/128)
				if k==0 then
					zero = true
				end
			end

			if not zero then
				for i, v in ipairs(ops) do
					ops[i] = opsNames[v]
				end

				total = total + v

				table.insert(stats, {count=v, names=ops})
			end
		end

		table.sort(stats, function(x, y) return x.count>y.count end)
		local report = {}

		for _, stat in ipairs(stats) do
			local pp = 100*stat.count/total
			if pp>1 then
				table.insert(report, string.format("%-50s %4i (%i%%)", table.concat(stat.names, " "), stat.count, pp))
			end
		end

		return table.concat(report, "\n")
	end
end
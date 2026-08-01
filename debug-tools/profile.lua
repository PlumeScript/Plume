--[[
This file is part of Plume🪶

Copyright © Erwan Barbedor
Licensed under the MIT License — see LICENSE for details.
]]

return function (plume)
	local jp = require "jit.profile"

	-- vmstate labels (see LuaJIT profiler docs)
	local STATE_LABELS = {
		N = "Compilé (JIT)",
		J = "JIT (trace)",
		I = "Interpréteur",
		C = "Fonctions C",
		G = "GC",
	}
	local STATE_ORDER = { "N", "J", "I", "C", "G" }

	--- Quick statistical profile of a Plume program: % of time in compiled
	--- code, top hot lines, and JIT NYI aborts. Requires a LuaJIT build with
	--- a working jit.profile (the stock luajit, not the custom bin\luajit).
	--- @param srcfile string Path to the .plume file to profile
	--- @return string The report
	function plume.debug.profileQuick(srcfile)
		local f = io.open(srcfile, "r")
		if not f then
			return "Cannot open file '" .. srcfile .. "'"
		end
		f:close()

		-- Capture JIT abort reasons (NYI, blacklisted, ...).
		local aborts = {}
		local function onAbort(trace, reason)
			aborts[#aborts + 1] = reason
		end
		jit.attach(onAbort, "abort")

		-- Statistical sampling: vmstate distribution + hot lines.
		local agg = { total = 0, byState = {}, byLine = {} }
		jp.start("l", function(thread, samples, vmstate)
			agg.total = agg.total + samples
			agg.byState[vmstate] = (agg.byState[vmstate] or 0) + samples
			local dump = jp.dumpstack(thread, "l\n", 1)
			local line = dump:match("^([^\n]+)") or "?"
			agg.byLine[line] = (agg.byLine[line] or 0) + samples
		end)

		local t0 = os.clock()
		local ok, result = plume.executeFile(srcfile, nil, nil, nil, true)
		local elapsed = os.clock() - t0

		jp.stop()
		jit.attach(onAbort, "abort")

		local out = {}
		local function line(s) out[#out + 1] = s end

		line("Plume JIT profile (quick) — " .. srcfile)
		line(string.rep("=", 40))

		-- JIT health
		line("JIT health")
		if agg.total == 0 then
			line("  (aucun échantillon — programme trop court)")
		else
			local function pct(n) return 100 * n / agg.total end
			for _, st in ipairs(STATE_ORDER) do
				local n = agg.byState[st] or 0
				if n > 0 then
					line(string.format("  %-16s %5.1f%%", STATE_LABELS[st] or st, pct(n)))
				end
			end
		end
		line(string.format("  Temps total        : %.3fs", elapsed))

		-- Top hot lines
		line("")
		line("Top 5 lignes chaudes")
		local sorted = {}
		for k, v in pairs(agg.byLine) do
			table.insert(sorted, { k, v })
		end
		table.sort(sorted, function(a, b) return a[2] > b[2] end)
		if #sorted == 0 then
			line("  (aucune donnée de ligne)")
		else
			for i = 1, math.min(5, #sorted) do
				local pp = agg.total > 0 and (100 * sorted[i][2] / agg.total) or 0
				line(string.format("  %2d. %-40s %5.1f%%  (%d)", i, sorted[i][1], pp, sorted[i][2]))
			end
		end

		-- NYI aborts raised by the JIT compiler
		line("")
		line("NYI (levés par le compilateur JIT)")
		local nyi = {}
		for _, reason in ipairs(aborts) do
			if reason:match("NYI") then
				nyi[reason] = (nyi[reason] or 0) + 1
			end
		end
		local nyiSorted = {}
		for k, v in pairs(nyi) do
			table.insert(nyiSorted, { k, v })
		end
		table.sort(nyiSorted, function(a, b) return a[2] > b[2] end)
		if #nyiSorted == 0 then
			line("  (aucun)")
		else
			for _, e in ipairs(nyiSorted) do
				line(string.format("  %-50s %d", e[1], e[2]))
			end
		end

		return table.concat(out, "\n")
	end
end

--[[
This file is part of Plume🪶

Copyright © Erwan Barbedor
Licensed under the MIT License — see LICENSE for details.
]]

return function (plume)
	local jp = require "jit.profile"
	local lfs = require "lfs"

	-- vmstate labels (see LuaJIT profiler docs)
	local STATE_LABELS = {
		N = "Compilé (JIT)",
		J = "JIT (trace)",
		I = "Interpréteur",
		C = "Fonctions C",
		G = "GC",
	}
	local STATE_ORDER = { "N", "J", "I", "C", "G" }

	local function readFile(path)
		local f = io.open(path, "r")
		if not f then return nil end
		local content = f:read("*a")
		f:close()
		return content
	end

	-- Strip ANSI SGR color codes (jit.dump colors its output by default).
	local function stripANSI(s)
		return (s:gsub("\27%[[^m]*m", ""))
	end

	--- Run the program once under jit.profile (line mode): vmstate
	--- distribution + per-line samples + wall time. Clean timing pass.
	local function runProfilePass(srcfile)
		local agg = { total = 0, byState = {}, byLine = {} }
		jp.start("l", function(thread, samples, vmstate)
			agg.total = agg.total + samples
			agg.byState[vmstate] = (agg.byState[vmstate] or 0) + samples
			local dump = jp.dumpstack(thread, "l\n", 1)
			local line = dump:match("^([^\n]+)") or "?"
			agg.byLine[line] = (agg.byLine[line] or 0) + samples
		end)
		local t0 = os.clock()
		plume.executeFile(srcfile, nil, nil, nil, true)
		agg.elapsed = os.clock() - t0
		jp.stop()
		return agg
	end

	--- Parse a jit.dump log into per-trace entries, aggregated by trace
	--- number (first root line, final status, last abort reason, full body).
	local function parseTraceDump(content)
		local traces = {}
		local byNum = {}
		local current
		for line in content:gmatch("[^\n]+") do
			local num, event, rest = line:match("^%-%-%-%- TRACE (%d+) (%S+) ?(.*)$")
			if num then
				num = tonumber(num)
				current = byNum[num]
				if not current then
					current = { num = num, body = {} }
					byNum[num] = current
					traces[#traces + 1] = current
				end
				if event == "start" then
					if not current.root then
						current.root = rest:match("(%S+:%d+)$") or rest
					end
				elseif event == "stop" then
					current.status = "compiled"
				elseif event == "abort" then
					current.status = "aborted"
					current.reason = rest:match("%-%- (.*)$") or rest
				elseif event == "blacklisted" then
					current.status = "blacklisted"
				else
					current.body[#current.body + 1] = line
				end
			else
				if current then
					current.body[#current.body + 1] = line
				end
			end
		end
		return traces
	end

	--- Run the program once under jit.dump + jit.attach("abort"): captures
	--- the full trace dumps and the abort reasons. Overhead-heavy pass.
	local function runTracePass(srcfile)
		local jitdump = require "jit.dump"
		local tmp = os.tmpname()
		jitdump.start("tmi", tmp)
		local aborts = {}
		local function onAbort(trace, reason)
			aborts[#aborts + 1] = reason
		end
		jit.attach(onAbort, "abort")
		plume.executeFile(srcfile, nil, nil, nil, true)
		jitdump.off()
		jit.attach(onAbort, "abort")
		local content = readFile(tmp)
		os.remove(tmp)
		return { traces = parseTraceDump(stripANSI(content or "")), aborts = aborts }
	end

	-- basename -> path map of every .lua file under plume-data (for snippets)
	local fileMap
	local function buildFileMap()
		if fileMap then return fileMap end
		fileMap = {}
		local function walk(dir)
			for entry in lfs.dir(dir) do
				if entry ~= "." and entry ~= ".." then
					local path = dir .. "/" .. entry
					local attr = lfs.attributes(path)
					if attr then
						if attr.mode == "directory" then
							walk(path)
						elseif attr.mode == "file" and entry:match("%.lua$") then
							if not fileMap[entry] then
								fileMap[entry] = path
							end
						end
					end
				end
			end
		end
		walk("plume-data")
		return fileMap
	end

	--- Best-effort source snippet for a "file:line" root.
	local function sourceSnippet(root)
		local file, line = root:match("^(.-):(%d+)$")
		if not file then return nil end
		local path = buildFileMap()[file]
		if not path then return nil end
		local content = readFile(path)
		if not content then return nil end
		local n = 0
		for l in content:gmatch("[^\n]+") do
			n = n + 1
			if n == tonumber(line) then
				return string.format("%d: %s", n, l)
			end
		end
		return nil
	end

	local function formatHealth(agg)
		local out = {}
		out[#out + 1] = "JIT health"
		if agg.total == 0 then
			out[#out + 1] = "  (aucun échantillon — programme trop court)"
		else
			local function pct(n) return 100 * n / agg.total end
			for _, st in ipairs(STATE_ORDER) do
				local n = agg.byState[st] or 0
				if n > 0 then
					out[#out + 1] = string.format("  %-16s %5.1f%%", STATE_LABELS[st] or st, pct(n))
				end
			end
		end
		out[#out + 1] = string.format("  Temps total        : %.3fs", agg.elapsed)
		return out
	end

	local function formatLines(agg, limit)
		local out = {}
		local sorted = {}
		for k, v in pairs(agg.byLine) do
			table.insert(sorted, { k, v })
		end
		table.sort(sorted, function(a, b) return a[2] > b[2] end)
		if #sorted == 0 then
			out[#out + 1] = "  (aucune donnée de ligne)"
		else
			local n = limit and math.min(limit, #sorted) or #sorted
			for i = 1, n do
				local pp = agg.total > 0 and (100 * sorted[i][2] / agg.total) or 0
				out[#out + 1] = string.format("  %2d. %-40s %5.1f%%  (%d)", i, sorted[i][1], pp, sorted[i][2])
			end
		end
		return out
	end

	local function formatNYI(aborts)
		local out = {}
		local nyi = {}
		for _, reason in ipairs(aborts) do
			if reason:match("NYI") then
				nyi[reason] = (nyi[reason] or 0) + 1
			end
		end
		local sorted = {}
		for k, v in pairs(nyi) do
			table.insert(sorted, { k, v })
		end
		table.sort(sorted, function(a, b) return a[2] > b[2] end)
		if #sorted == 0 then
			out[#out + 1] = "  (aucun)"
		else
			for _, e in ipairs(sorted) do
				out[#out + 1] = string.format("  %-50s %d", e[1], e[2])
			end
		end
		return out
	end

	--- Quick statistical profile of a Plume program: % of time in compiled
	--- code, top hot lines, and JIT NYI aborts. Requires a LuaJIT build with
	--- a working jit.profile.
	--- @param srcfile string Path to the .plume file to profile
	--- @return string The report
	function plume.debug.profileQuick(srcfile)
		local f = io.open(srcfile, "r")
		if not f then
			return "Cannot open file '" .. srcfile .. "'"
		end
		f:close()

		local aborts = {}
		local function onAbort(trace, reason)
			aborts[#aborts + 1] = reason
		end
		jit.attach(onAbort, "abort")

		local agg = runProfilePass(srcfile)

		jit.attach(onAbort, "abort")

		local out = {}
		out[#out + 1] = "Plume JIT profile (quick) — " .. srcfile
		out[#out + 1] = string.rep("=", 40)
		for _, l in ipairs(formatHealth(agg)) do out[#out + 1] = l end
		out[#out + 1] = ""
		out[#out + 1] = "Top 5 lignes chaudes"
		for _, l in ipairs(formatLines(agg, 5)) do out[#out + 1] = l end
		out[#out + 1] = ""
		out[#out + 1] = "NYI (levés par le compilateur JIT)"
		for _, l in ipairs(formatNYI(aborts)) do out[#out + 1] = l end

		return table.concat(out, "\n")
	end

	--- Full statistical profile: JIT health, all hot lines, and the JIT
	--- traces (from jit.dump) sorted by the hotness of their root line, each
	--- with its status, abort reason, source snippet and full dump. Two
	--- passes: one clean timing pass (jit.profile), one trace-capture pass
	--- (jit.dump + jit.attach).
	--- @param srcfile string Path to the .plume file to profile
	--- @return string The report
	function plume.debug.profileFull(srcfile)
		local f = io.open(srcfile, "r")
		if not f then
			return "Cannot open file '" .. srcfile .. "'"
		end
		f:close()

		local agg = runProfilePass(srcfile)
		local pass2 = runTracePass(srcfile)

		-- Sort traces by hotness of their root line (proxy for time spent).
		local traces = pass2.traces
		for _, t in ipairs(traces) do
			t.hotness = agg.byLine[t.root] or 0
		end
		table.sort(traces, function(a, b)
			if a.hotness ~= b.hotness then return a.hotness > b.hotness end
			return a.num < b.num
		end)

		local out = {}
		out[#out + 1] = "Plume JIT profile (full) — " .. srcfile
		out[#out + 1] = string.rep("=", 40)
		for _, l in ipairs(formatHealth(agg)) do out[#out + 1] = l end

		out[#out + 1] = ""
		out[#out + 1] = "Lignes chaudes"
		for _, l in ipairs(formatLines(agg)) do out[#out + 1] = l end

		out[#out + 1] = ""
		out[#out + 1] = "NYI (levés par le compilateur JIT)"
		for _, l in ipairs(formatNYI(pass2.aborts)) do out[#out + 1] = l end

		out[#out + 1] = ""
		out[#out + 1] = "Traces (triées par hotness de la ligne racine)"
		if #traces == 0 then
			out[#out + 1] = "  (aucune trace)"
		else
			for _, t in ipairs(traces) do
				local status = t.status or "?"
				local reason = t.reason and ("  " .. t.reason) or ""
				out[#out + 1] = string.format("  TRACE %-3d %-30s %s%s", t.num, t.root or "?", status, reason)
				out[#out + 1] = string.format("    hotness: %d échantillons (ligne racine)", t.hotness)
				local snippet = sourceSnippet(t.root)
				if snippet then
					out[#out + 1] = "    ── snippet ──"
					out[#out + 1] = "    " .. snippet
					out[#out + 1] = "    ─────────────"
				end
				if #t.body > 0 then
					for _, bl in ipairs(t.body) do
						out[#out + 1] = "    " .. bl
					end
				end
				out[#out + 1] = ""
			end
		end

		return table.concat(out, "\n")
	end
end

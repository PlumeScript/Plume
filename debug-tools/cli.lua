--[[
This file is part of Plume🪶

Copyright © Erwan Barbedor
Licensed under the MIT License — see LICENSE for details.
]]

package.path  = arg[1] .. "?.lua;"
             .. arg[1] .. "lua/?.lua;"
             .. package.path
package.cpath = arg[1] .. "bin/?.so;"
             .. package.cpath

local plume = require "plume-data/engine/init"
require "debug-tools/core" (plume)

local action  = arg[2]
local srcfile = arg[3]

local function readFile(path)
	local f = io.open(path, "r")
	if not f then
		io.stderr:write("Cannot open file '" .. path .. "'\n")
		return nil
	end
	local content = f:read("*a")
	f:close()
	return content
end

if action == "decomp" then
	if not srcfile then
		io.stderr:write("Usage: plume-debug decomp <srcfile>\n")
		return
	end
	local code = readFile(srcfile)
	if not code then
		return
	end
	local success, result = plume.debug.decomp(code, srcfile)
	if not success then
		io.stderr:write(result .. "\n")
	end
elseif action == "hotspots" then
	if not srcfile then
		io.stderr:write("Usage: plume-debug hotspots <srcfile>\n")
		return
	end
	plume.runStatFlag = true
	local runtime = plume.obj.runtime()
	local success, result = plume.executeFile(srcfile, runtime, nil, nil, true)
	if not success then
		io.stderr:write(result .. "\n")
	end
	local ipcount = runtime.vm and runtime.vm.stats and runtime.vm.stats.ipcount
	if not ipcount then
		io.stderr:write("No statistics gathered.\n")
		return
	end

	-- Build a bpos -> line index per distinct source
	local lineIndexCache = {}
	local function lineOf(node)
		local code = node.code
		local idx = lineIndexCache[code]
		if not idx then
			idx = {}
			local line = 1
			for i = 1, #code do
				idx[i] = line
				if code:sub(i, i) == "\n" then
					line = line + 1
				end
			end
			lineIndexCache[code] = idx
		end
		return idx[node.bpos]
	end

	local counts = {}
	local nodes = {}
	for ip, count in pairs(ipcount) do
		local node = runtime.mapping[ip]
		if node and node.code and node.bpos then
			local line = lineOf(node)
			if line then
				local filename = node.filename or "?"
				counts[filename] = counts[filename] or {}
				counts[filename][line] = (counts[filename][line] or 0) + count
				nodes[filename] = nodes[filename] or {}
				nodes[filename][line] = node
			end
		end
	end

	local sorted = {}
	for filename, byLine in pairs(counts) do
		for line, count in pairs(byLine) do
			table.insert(sorted, {filename=filename, line=line, count=count})
		end
	end
	table.sort(sorted, function(a, b) return a.count > b.count end)

	local total = 0
	for _, s in ipairs(sorted) do total = total + s.count end
	for _, s in ipairs(sorted) do
		local node = nodes[s.filename][s.line]
		local content = node.code:sub(node.bpos, node.epos)
		if content:match('\n') then
			content = content:match('^[^\n]*') .. "[...]"
		end
		local pp = 100 * s.count / total
		print(string.format("%-30s %6d (%2d%%)  %s", s.filename .. ":" .. s.line, s.count, pp, content))
	end
else
	local deep = action:match("^opusage(%d+)$")
	if deep then
		if not srcfile then
			io.stderr:write("Usage: plume-debug opusage" .. deep .. " <srcfile>\n")
			return
		end
		plume.runStatFlag = true
		plume.runStatDeep = tonumber(deep)
		local success, result = plume.executeFile(srcfile, nil, nil, nil, true)
		if not success then
			io.stderr:write(result .. "\n")
		end
		if plume.stats then
			print(plume.getOpcodeUsageReport())
		end
	else
		io.stderr:write("Unknown action '" .. tostring(action) .. "'\n")
		io.stderr:write("Available actions: decomp, hotspots, opusage1, opusage2, ...\n")
	end
end

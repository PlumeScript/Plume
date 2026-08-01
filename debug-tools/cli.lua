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
		io.stderr:write("Available actions: decomp, opusage1, opusage2, ...\n")
	end
end

--[[
This file is part of Plume🪶

Copyright © Erwan Barbedor
Licensed under the MIT License — see LICENSE for details.
]]

lfs = {
	currentdir = function ()
		local cmd = "cd"
		local handle = io.popen(cmd)
		if not handle then return nil end
		local cwd = handle:read("*a")
		handle:close()
		cwd = cwd:gsub("[\r\n]+$", "")
		return cwd
	end
}
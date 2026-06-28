--[[
This file is part of Plume🪶

Copyright © Erwan Barbedor
Licensed under the MIT License — see LICENSE for details.
]]

-- plume.std.plume isn't loaded like other std table,
-- but copied at runtime creation

plume.std.plume = plume.obj.quickTable {
	doc = plume.obj.luaMacro("doc", function (args)
		--!signature macro|table m
		return true, m.type .. " " .. (m.debugMacroName or m.name or "???") .. "\n    " .. (m.doc or ""):gsub('\n', '\n    ')
	end)
}
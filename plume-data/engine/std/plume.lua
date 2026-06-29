--[[
This file is part of Plume🪶

Copyright © Erwan Barbedor
Licensed under the MIT License — see LICENSE for details.
]]

-- plume.std.plume isn't loaded like other std table,
-- but copied at runtime creation

function plume.makedoc(m)
	return m.type .. " " .. (m.debugMacroName or m.name or "???") .. "\n    " .. (m.doc or ""):gsub('\n', '\n    ')
end

plume.std.plume = plume.obj.quickTable {
	doc = plume.obj.luaMacro("doc", function (args)
		--!signature macro|table m
		return true, plume.makedoc(m)
	end)
}
plume.std.plume.name = "plume"
plume.std.plume:setMetaItem('readonly', true)
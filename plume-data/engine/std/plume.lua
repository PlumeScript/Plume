--[[
This file is part of Plume🪶

Copyright © Erwan Barbedor
Licensed under the MIT License — see LICENSE for details.
]]

return function (plume)
	-- plume.std.plume isn't loaded like other std table,
	-- but copied at runtime creation

	plume.std.plume = plume.obj.table(0, 0)

	plume.std.plume.table.doc = {
		checkArgs = {
			checkTypes = {"macro"},
			signature  = "macro m",
			named      = {self=true},
			args       = 1
		},
		method = function (m)
			return true, "macro " .. (m.debugMacroName or m.name) .. "\n    " .. m.doc:gsub('\n', '\n    ') or ""
		end
	}
end
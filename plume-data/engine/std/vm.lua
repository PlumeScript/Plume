--[[
This file is part of Plume🪶

Copyright © Erwan Barbedor
Licensed under the MIT License — see LICENSE for details.
]]

return function (plume)
	plume.stdVM = {}
	local function registerLuaStdFunction(name, minArgs, maxArgs)
		if not minArgs then
			minArgs = 0
		end
		if not maxArgs then
			maxArgs = minArgs
		end

		plume.stdVM[name] = {
			type = "stdMacro",
			name = name,
			opcode = plume.ops_count,
			minArgs = minArgs,
			maxArgs = maxArgs
		}
		
		local opName = "STD_" .. name:upper()
		plume.ops[opName] = plume.ops_count
		plume.ops_names = plume.ops_names .. " " .. opName
		plume.ops_count = plume.ops_count + 1

	end

	registerLuaStdFunction("len", 1)
	registerLuaStdFunction("type", 1)
	registerLuaStdFunction("seq", 1, 3)
	registerLuaStdFunction("items", 1)
	registerLuaStdFunction("enumerate", 1)
	registerLuaStdFunction("import", 1)
end
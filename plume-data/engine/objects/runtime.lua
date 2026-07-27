--[[
This file is part of Plume🪶

Copyright © Erwan Barbedor
Licensed under the MIT License — see LICENSE for details.
]]

return function(plume)

	local function makePlumeTable()
		local result = plume.obj.table(0, 2)

		for k, v in pairs(plume.std) do
			result:setItem(k, v)
		end

		local pathTable = plume.obj.table(0, 0)
		for path in (os.getenv("PLUME_PATH") or ""):gmatch('[^;]+') do
			pathTable:addItem(path)
		end
		result:setItem("path", pathTable)
		for _, key in ipairs(plume.std.plume.keys) do
			result:setItem(key, plume.std.plume.table[key])
		end

		result:setItem("locale", plume.obj.context(plume.obj.empty))
		result:setItem("localeNumberFormat", plume.obj.context(plume.obj.empty))
		result:setItem("localeThousandsSeparator", plume.obj.context(plume.obj.empty))
		result:setItem("localeDecimalSeparator", plume.obj.context(plume.obj.empty))
		result:setItem("localeThousandthsSeparator", plume.obj.context(plume.obj.empty))

		result:setItem("VERSION", plume.VERSION)
		return result
	end

	function plume.obj.runtime()
		plume.lastErrorInfos = nil
		plume.warning.cache = {}
		plume.warning.any = false
		plume.warning.mode = {
			default = {global = "normal"},
			["381"] = {global = "ignore"}
		}
		plume.currentUseProcessing = {}

		return {
			type = "runtime",
			instructions = {},
			insert = {},
			linkedInstructions = {},
			bytecode = {},
			constants = {},
			mapping = {},
			callstack = {},
			files = {},
			cache = {chunks = {}, results = {}},
			contextCount = 0,
			plume = makePlumeTable()
		}
	end

end
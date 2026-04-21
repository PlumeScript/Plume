--[[
This file is part of Plume🪶

Copyright © Erwan Barbedor
Licensed under the MIT License — see LICENSE for details.
]]

return function (plume)
	function plume.stdArgsCheck(name, args, signature)
		local argsCount = signature.args
		local minArgsCount = signature.minArgs or argsCount
		local maxArgsCount = signature.maxArgs or argsCount
		
		if minArgsCount or maxArgsCount then
			if (minArgsCount and #args.table < minArgsCount) or (maxArgsCount and #args.table > maxArgsCount) then
				return false, plume.error.wrongArgsCountStd(
					name, #args.table, minArgsCount, maxArgsCount, signature.signature
					
				)
			end
		end

		if signature.checkTypes or signature.named or signature.checkTypesAll then
			for key, value in pairs(args.table) do
				if not tonumber(key)
				and (not signature.named      or (not signature.named[key] and not signature.named["*"]))
				and (not signature.checkTypes or not signature.checkTypes[key]) then
					return false, plume.error.unknownParameterStd(key, name, signature.signature)
				end
				local exectedTypeTable = signature.checkTypes and signature.checkTypes[key] or signature.checkTypesAll
				local found = false
				local t

				for i, exectedType in ipairs(exectedTypeTable or {}) do
					t = type(value)
					if t == "table" then
						t = value.type or "table"
					end
					if exectedType == "string" and t == "number" then
						t = "string"
						args.table[key] = tostring(value)
					elseif exectedType == "number" and t == "string" and tonumber(value) then
						t = "number"
						args.table[key] = tonumber(value)
					end

					if t == "table" then
						t = t.type or t
					end

					if exectedType == t then
						found = true
						break
					end
				end

				if exectedTypeTable and not found then
					return false, plume.error.wrongArgTypeStd(key, name, t, table.concat(exectedTypeTable, '|'), signature.signature)
				end
			end
		end

		return true
	end
end
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

	local function makeSignature(name, signature)
		return  "`$"..name.."("..signature..")`"
	end

	function plume.stdUnpackPositional (args, minArgs, maxArgs, name, signature)
		if #args.table < minArgs or #args.table > maxArgs then
			return false, plume.error.wrongArgsCountStd(
					name, #args.table, minArgs, maxArgs, makeSignature(name, signature)
				)
		end

		return true, nil, unpack(args.table)
	end

	function plume.stdUnpackNamed(args, nameds, name, signature)
		local result = {}

		for _, key in ipairs(nameds) do
			nameds[key] = true
			if args.table[key] then
				table.insert(result, args.table[key])
			else
				table.insert(result, false)
			end
		end

		for _, key in ipairs(args.keys) do
			if not tonumber(key) then
				if nameds and nameds[key] then
					table.insert(result, args.table[key])
				else
					return false, plume.error.unknownParameterStd(key, name, makeSignature(name, signature))
				end
			end
		end


		return true, nil, unpack(result)
	end

	function plume.stdCheckType(arg, expected, argName, name, signature)
		local given = type(arg)
		if type(arg) == "table" and arg.type then
			given = arg.type
		end
		if given == "luaMacro" or given == "stdMacro" then
			given = "macro"
		end

		if given == "string" and expected == "number" then
			if tonumber(arg) then
				arg = tonumber(arg)
				given = "number"
			end
		elseif given == "number" and expected == "string" then
			arg = tostring(arg)
			given = "string"
		end

		if given == expected then
			return true, nil, arg
		else
			return false, plume.error.wrongArgTypeStd(
				argName, name, given, expected, makeSignature(name, signature)
			), arg
		end
	end


end
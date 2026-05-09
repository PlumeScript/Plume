--[[
This file is part of Plume🪶

Copyright © Erwan Barbedor
Licensed under the MIT License — see LICENSE for details.
]]

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
		if expected ~= "table" and arg.subtype then
			given = arg.subtype
		else
			given = arg.type
		end
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
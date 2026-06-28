--[[
This file is part of Plume🪶

Copyright © Erwan Barbedor
Licensed under the MIT License — see LICENSE for details.
]]

--- Check for meta-macro args count.
--- Should certainly be handled by the compilator, no?
--- @param name string Operator's name
--- @param obj macro or closure
--! inline
function _META_CHECK (vm, name, obj)
	local comopps = "add mul div sub mod pow"
	local binopps = "eq lt"
	local unopps = "minus"

	

	local expectedParamCount
	for opp in comopps:gmatch('%S+') do
		if name == opp then
			expectedParamCount = 2
		elseif name:match("^" .. opp .. "[rl]") then
			expectedParamCount = 1
		end
	end
	for opp in binopps:gmatch('%S+') do
		if name == opp then
			expectedParamCount = 2
		end
	end
	for opp in unopps:gmatch('%S+') do
		if name == opp then
			expectedParamCount = 0
		end
	end

	if expectedParamCount then
		local t = _GET_TYPE(vm, obj)
		local metaValue = obj
		if t == "closure" then
			metaValue = obj.macro
			t = "macro"
		end

		if t == "macro" then
			if metaValue.positionalParamCount ~= expectedParamCount then
				return false, vm.plume.error.wrongArgsCountMetaDefinition(
					name, metaValue.positionalParamCount, expectedParamCount
				)
			end
			if metaValue.namedParamCount > 1 then -- 1 for self
				return false, vm.plume.error.metaMacroWithoutNamedParameter(name)
			end
		else
			return false, vm.plume.error.wrongMetaFieldType(name, t, "macro")
		end
	else
		return _META_CHECK_NAME(vm, name)
	end

	return true
end

--! inline
function _META_CHECK_NAME(vm, name)
	if vm.plume.validMetaNames[name] then
		return true
	else
		return false, "'" .. name .. "' isn't a valid meta-macro name."
	end
end
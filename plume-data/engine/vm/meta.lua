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

	local macro = obj.macro or obj -- in case of closure

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
		if macro.positionalParamCount ~= expectedParamCount then
			return false, vm.plume.error.wrongArgsCountMetaDefinition(macro, name, macro.positionalParamCount, expectedParamCount)
		end
		if macro.namedParamCount > 1 then -- 1 for self
			return false, vm.plume.error.metaMacroWithoutNamedParameter(name)
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
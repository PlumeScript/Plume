--[[
This file is part of Plume🪶

Copyright © Erwan Barbedor
Licensed under the MIT License — see LICENSE for details.
]]

return function(vm)
	--- Check for meta-macro args count.
	--- Should certainly be handled by the compilator, no?
	--- @param name string Operator's name
	--- @param obj macro or closure
	--! inline
	function vm:_META_CHECK(name, obj)
		local comopps = "add mul div sub mod pow"
		local binopps = "eq lt"
		local unopps  = "minus fragment tostring"
		local varopps = "call"

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
		for opp in varopps:gmatch('%S+') do
			if name == opp then
				expectedParamCount = -1
			end
		end

		if expectedParamCount then
			local t = self:_GET_TYPE(obj)
			local metaValue = obj
			if t == "closure" then
				metaValue = obj.macro
				t = "macro"
			end

			if t == "macro" then
				if expectedParamCount ~= -1 then
					if metaValue.positionalParamCount ~= expectedParamCount then
						return false, self.plume.error.wrongArgsCountMetaDefinition(
							name, metaValue.positionalParamCount, expectedParamCount
						)
					end
					if metaValue.namedParamCount > 1 then -- 1 for self
						return false, self.plume.error.metaMacroWithoutNamedParameter(name)
					end
				end
			elseif (t ~= "string" or name ~= "tostring") then
				local expected
				if name == "tostring" then
					expected = "macro or string"
				else
					expected = "macro"
				end
				return false, self.plume.error.wrongMetaFieldType(name, t, expected)
			end
		else
			return self:_META_CHECK_NAME(name)
		end

		return true
	end

	--! inline
	function vm:_CHECK_META_FRAGMENT(meta, name)
		local fragmentIncompatible = "add addr addl mul mull mulr div divr divl sub subr subl mod modr modl pow powl powr eq lt minus call tostring validate readonly"
		if meta then
			for s in fragmentIncompatible:gmatch('%S+') do
				if meta.table[s] and name == "fragment" or meta.table.fragment and s == name then
					self:_ERROR(
						self.plume.error.incompatibleMetaFields(name, s),
						self:_STACK_GET(self.mainStack.frames)-1-- move errip to frame bottom
					)
				end
			end
		end
	end

	--! inline
	function vm:_META_CHECK_NAME(name)
		if self.plume.validMetaNames[name] then
			return true
		else
			return false, "'" .. name .. "' isn't a valid meta-macro name."
		end
	end
end

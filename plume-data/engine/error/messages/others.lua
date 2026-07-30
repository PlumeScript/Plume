--[[
This file is part of Plume🪶

Copyright © Erwan Barbedor
Licensed under the MIT License — see LICENSE for details.
]]

return function(plume)
	function plume.error.stackOverflow()
		return "Stack overflow"
	end

	function plume.error.cannotUseEmptyAsKey()
		return "Cannot use empty as key."
	end

	function plume.error.getindexReturnsEmpty()
		return "User-defined getindex returns empty"
	end

	function plume.error.unregisteredKey(t, key)
		local index = tonumber(key)
		local tableHint = ""
		if t.name then
			tableHint = string.format(" for table '%s'", t.name)
		end

		if index and math.floor(index) == index and index ~= 0 then
			if index < 0 then
				hint = string.format("To count from the end, use `$t[len(t)%s+1]` or `Table.at($t, %s)`.", key, key)
				return string.format("Unregistered key '%s'.\n(i) %s",  key, hint)
			end

			local largestIndex = 0
			for _, testkey in ipairs(t.keys) do
				largestIndex = math.max(largestIndex, tonumber(testkey) or 0)
			end

			local hole = false
			for i=1, largestIndex do
				if not t.table[i] then
					hole = true
				end
			end

			local hint = ""
			if largestIndex > 0 then
				if not hole then
					hint = string.format("The largest index in this table is %i.", largestIndex)
				end
			else
				hint = "This table does not include any numerical indexes."
			end

			return string.format("Invalid index '%s'%s.\n%s",  key, tableHint, hint)
		else
			local hint = plume.error.makeVisibleKeysHint(key, t.keys)
			return string.format("Unregistered key '%s'%s.%s",  key, tableHint, hint)
		end
	end

	function plume.error.cannotUseMetaKey()
		return "Cannot use a meta key for a macro named argument."
	end

	function plume.error.wrongContextType(var)
		local t = type(var)
		if t == "table" then
			t = var.type
		end

		return string.format("Cannot use a '%s' as contextual variable. Use `$Context()` to create one.", t)
	end

	function plume.error.cannotSetIndexReadonlyTable()
		return "Cannot set index of a readonly table."
	end

	function plume.error.tryToUseFragmentInsideItSelf(fragment)
		local repr = plume.repr(fragment)
		if #repr > 20 then
			repr = repr:sub(1, 16) .. "...)"
		end
		return string.format("Circular fragment reference: The table `%s` references itself within its meta-macro fragment.", repr)
	end

	function plume.error.incompatibleMetaFields(a, b)
		return string.format(
			"Unable to create a table with both '%s' and '%s' metafields.\n(i) Check 'doc/expert.md' for more information.",
			a, b)
	end
end
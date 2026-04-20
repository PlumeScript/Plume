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

	function plume.error.unregisteredKey(t, key)
		local index = tonumber(key)
		if index and math.floor(index) == index then
			local largestIndex = 0
			for _, key in ipairs(t.keys) do
				largestIndex = math.max(largestIndex, tonumber(key) or 0)
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

			return string.format("Invalid index '%s'.\n%s",  key, hint)
		else
			hint = plume.error.makeVisibleKeysHint(key, t.keys)
			return string.format("Unregistered key '%s'.%s",  key, hint)
		end
	end

	function plume.error.cannotUseMetaKey()
		return "Cannot use a meta key for a macro named argument."
	end
end
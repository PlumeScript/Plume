--[[
This file is part of Plume🪶

Copyright © Erwan Barbedor
Licensed under the MIT License — see LICENSE for details.
]]

return function(plume)
	function plume.error.joinErrorHint()
		return "Wrong type 'table' for parameter '1' of macro 'join'.\n"
			 .."Did you write `Table.join($t)` instead of `Table.join(...t)`?"
	end

	function plume.error.sumErrorHint()
		return "Wrong type 'table' for parameter '1' of macro 'sum'.\n"
			 .."Did you write `Table.sum($t)` instead of `Table.sum(...t)`?"
	end

	function plume.error.cannotRemoveNotfoundKey(key)
		return string.format("The key '%s' does not exist and therefore cannot be deleted.", key)
	end

	function plume.error.cannotUseDegRadTogether()
		return "Cannot use `?deg` and `?rad` flags together."
	end

	function plume.error.seqCannotUseNulStep()
		return "Cannot set `step` to zero (will lead to an infinite loop)."
	end
end
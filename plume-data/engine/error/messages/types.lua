--[[
This file is part of Plume🪶

Copyright © Erwan Barbedor
Licensed under the MIT License — see LICENSE for details.
]]

return function(plume)
	function plume.error.cannotConcatValue(t)
		return string.format("Cannot concat a '%s' value.", t)
	end

	function plume.error.cannotCallValue(t)
		return string.format("Cannot call a '%s' value.", t)
	end

	function plume.error.cannotIterateValue(t)
		return string.format("Cannot iterate over a non-table '%s' value.", t)
	end

	function plume.error.cannotIndexValue(t)
		return string.format("Cannot index a non-table '%s' value.", t)
	end

	function plume.error.cannotExpandValue(t)
		return string.format("Cannot expand a non-table '%s' value.", t)
	end

	function plume.error.hasNoLen(tt)
		return string.format("Type '%s' has no len.", tt)
	end

	function plume.error.cannotConvertToString(x)
		return string.format("Cannot convert the string value '%s' to a number.", plume.repr(x))
	end

	function plume.error.cannotDoArithmeticWith(_type)
		return string.format("Cannot do comparison or arithmetic with a %s value.", _type)
	end
end
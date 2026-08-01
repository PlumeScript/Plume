--[[
This file is part of Plume🪶

Copyright © Erwan Barbedor
Licensed under the MIT License — see LICENSE for details.
]]

return function(plume)
	function plume.error.cannotConcatValue(t)
		local hint = ""

		if t == "context" then
			hint = "\n(i) Use `$varname()` instead of `$varname`"
		end

		return string.format("Cannot concat a '%s' value.%s", t, hint)
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

	function plume.error.wrongMetaFieldType(name, _type, expected)
		return string.format("Wrong type '%s' for meta field '%s'. Expected '%s'.", _type, name, expected)
	end

	function plume.error.wrongTostringReturnType(stringValueType)
		return string.format("`tostring` metamacro returning `%s` instead of `string`.", stringValueType)
	end
end
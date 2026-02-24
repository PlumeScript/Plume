--[[This file is part of Plume

Plume🪶 is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, version 3 of the License.

Plume🪶 is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with Plume🪶.
If not, see <https://www.gnu.org/licenses/>.
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
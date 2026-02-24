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
	function plume.error.stackOverflow()
		return "Stack overflow"
	end

	function plume.error.cannotUseEmptyAsKey()
		return "Cannot use empty as key."
	end

	function plume.error.invalidKey(key)
		if tonumber(key) then
			return string.format("Invalid index '%s'.",  key)
		else
			return string.format("Invalid key '%s'.",  key)
		end
	end

	function plume.error.unregisteredKey(key)
		return string.format("Unregistered key '%s'.",  key)
	end

	function plume.error.cannotUseMetaKey()
		return "Cannot use a meta key for a macro named argument."
	end
end
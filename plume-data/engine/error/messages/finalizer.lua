-- --[[This file is part of Plume

-- Plume🪶 is free software: you can redistribute it and/or modify
-- it under the terms of the GNU General Public License as published by
-- the Free Software Foundation, version 3 of the License.

-- Plume🪶 is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
-- See the GNU General Public License for more details.

-- You should have received a copy of the GNU General Public License along with Plume🪶.
-- If not, see <https://www.gnu.org/licenses/>.
-- ]]

return function(plume)
	function plume.error.toManyInstructions(node, current, max)
		local message = string.format(
			"Compilation error: %i instructions requested (hard limit is %i).\n\n" ..
			"This is a hard architectural constraint - the instruction count cannot be encoded in Plume's bytecode format.",
			current, max
		)
		plume.error.throwCompilationError(node, message)
	end

	function plume.error.instructionFieldOverflow(node, name, current, max)
		local message = string.format(
			"Compilation error: field '%s' value %i exceeds maximum of %i.\n\n" ..
			"This is a hard limit - the bytecode format cannot encode values larger than this.",
			name, current, max
		)
		plume.error.throwCompilationError(node, message)
	end
end

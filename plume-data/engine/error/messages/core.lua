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
	function plume.error.throwCompilationError(node, message)
		message = plume.error.makeCompilationError(node, message)
		error(message, -1)
	end

	function plume.error.throwSyntaxError(node, message)
		message = plume.error.makeSyntaxError(node, message)
		error(message, -1)
	end

	function plume.error.strictWarningError (node, message)
		message = plume.error.makeStrictWarningError(node, message)
		error(message, -1)
	end

	require 'plume-data/engine/error/messages/import'    (plume)
	require 'plume-data/engine/error/messages/macros'    (plume)
	require 'plume-data/engine/error/messages/others'    (plume)
	require 'plume-data/engine/error/messages/syntax'    (plume)
	require 'plume-data/engine/error/messages/types'     (plume)
	require 'plume-data/engine/error/messages/variables' (plume)
	require 'plume-data/engine/error/messages/std'       (plume)
end
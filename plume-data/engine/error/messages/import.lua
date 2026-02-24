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
	function plume.error.unknownDirective(node, name)
		local message = string.format("Cannot use directive '%s': it doesn't exist.", name)
		plume.error.throwCompilationError(node, message)
	end

	function plume.error.compilationCannotOpenFile(node, path, searchPaths)
		local message = string.format("Cannot open '%s'.\nPaths tried:\n\t%s", path, table.concat(searchPaths, '\n\t'))
		plume.error.throwCompilationError(node, message)
	end

	function plume.error.cannotExecuteFile(node, path, error)
		local message = string.format("Error when executing '%s':\n%s", path, error)
		plume.error.throwCompilationError(node, message)
	end

	function plume.error.fileMustReturnATable(node, path, t)
		local message = string.format("To be used, '%s' must return a table. Currently, it returns a %s.", path, t)
		plume.error.throwCompilationError(node, message)
	end

	function plume.error.cannotOpenFile(path, searchPaths)
		return string.format("Error: cannot open '%s'.\nPaths tried:\n\t%s", path, table.concat(searchPaths, '\n\t'))
	end
end
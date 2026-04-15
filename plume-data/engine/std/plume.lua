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

return function (plume)
	-- plume.std.plume isn't loaded like other std table,
	-- but copied at runtime creation

	plume.std.plume = plume.obj.table(0, 0)

	plume.std.plume.table.doc = {
		checkArgs = {
			checkTypes = {"macro"},
			signature  = "macro m",
			named      = {self=true},
			args       = 1
		},
		method = function (m)
			return true, "macro " .. (m.debugMacroName or m.name) .. "\n    " .. m.doc:gsub('\n', '\n    ') or ""
		end
	}
end
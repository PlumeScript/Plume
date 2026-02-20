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
	local Number = plume.obj.table (0, 1)

	Number.table.keys = {"floor"}
	Number.table.floor = plume.obj.luaFunction("floor", function (args)
		local x = tonumber(args.table[1] or args.table.self)
		local digit = tonumber(args.table.digit)
		return math.floor(x, digit)
	end)

	plume.std.Number = Number
end
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
	local String = plume.obj.table (0, 2)
	String.table.keys = {"upper", "trim", "rtrim", "ltrim", "dedent", "collapse", "indent"}
	String.table.upper = plume.obj.luaFunction("upper", function (args)
		local x = args.table[1] or args.table.self
		return string.upper(x)
	end)

	-- Normalization
	String.table.trim = plume.obj.luaFunction("trim", function (args)
		local x = args.table[1] or args.table.self
		return x:gsub('^%s*', ''):gsub('%s*$', '')
	end)
	String.table.rtrim = plume.obj.luaFunction("rtrim", function (args)
		local x = args.table[1] or args.table.self
		return x:gsub('^%s*', '')
	end)
	String.table.ltrim = plume.obj.luaFunction("ltrim", function (args)
		local x = args.table[1] or args.table.self
		return x:gsub('%s*$', '')
	end)
	String.table.collapse = plume.obj.luaFunction("collapse", function (args)
		local x = args.table[1] or args.table.self
		return x:gsub('%s+', ' ')
	end)
	String.table.dedent = plume.obj.luaFunction("dedent", function (args)
		local x = args.table[1] or args.table.self
		local firstIndent = x:match('^%s+')
		return x:gsub('^'..firstIndent, ''):gsub('\n'..firstIndent, '\n')
	end)
	String.table.indent = plume.obj.luaFunction("indent", function (args)
		local x   = args.table[1] or args.table.self
		local sep = args.table.sep or "\t"
		return sep..x:gsub('\n', '\n'..sep)
	end)

	plume.std.String = String
end
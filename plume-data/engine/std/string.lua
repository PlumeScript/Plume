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
	local String = plume.obj.table (0, 14)
	String.table.keys = {
		"upper", "lower", "replace",
		"isNumber",
		"trim", "rtrim", "ltrim", "dedent", "collapse", "indent",
		"find", "count", "startsWith", "endsWith", "contains",
		"split", "lines", "findAll", "partition"
	}

	-- Manipulation
	String.table.upper = plume.obj.luaMacro("upper", function (args)
		local s = plume.shiftArgs(String, args)
		return string.upper(s)
	end)
	String.table.lower = plume.obj.luaMacro("lower", function (args)
		local s = plume.shiftArgs(String, args)
		return string.lower(s)
	end)
	String.table.replace = plume.obj.luaMacro("replace", function (args)
		local s, pattern, sub  = plume.shiftArgs(String, args)
		local pattern = tostring(pattern)
		local sub     = tostring(sub)

		if not args.table.rich then
			pattern = pattern:gsub("[%(%)%.%%%+%-%*%?%[%]%^%$]", "%%%1")
			sub     = sub:gsub("%%", "%%%%")
		end

		return s:gsub(pattern, sub)
	end)

	-- Tests
	String.table.isNumber = plume.obj.luaMacro("isNumber", function (args)
		local s = plume.shiftArgs(String, args)
		if tonumber(s) then
			return true
		else
			return false
		end
	end)

	-- Normalization
	String.table.trim = plume.obj.luaMacro("trim", function (args)
		local s = plume.shiftArgs(String, args)
		return s:gsub('^%s*', ''):gsub('%s*$', '')
	end)
	String.table.rtrim = plume.obj.luaMacro("rtrim", function (args)
		local s = plume.shiftArgs(String, args)
		return s:gsub('^%s*', '')
	end)
	String.table.ltrim = plume.obj.luaMacro("ltrim", function (args)
		local s = plume.shiftArgs(String, args)
		return s:gsub('%s*$', '')
	end)
	String.table.collapse = plume.obj.luaMacro("collapse", function (args)
		local s = plume.shiftArgs(String, args)
		return s:gsub('%s+', ' ')
	end)
	String.table.dedent = plume.obj.luaMacro("dedent", function (args)
		local s = plume.shiftArgs(String, args)
		local firstIndent = s:match('^%s+')
		return s:gsub('^'..firstIndent, ''):gsub('\n'..firstIndent, '\n')
	end)
	String.table.indent = plume.obj.luaMacro("indent", function (args)
		local s = plume.shiftArgs(String, args)
		local sep = args.table.sep or "\t"
		return sep..s:gsub('\n', '\n'..sep)
	end)

	-- search
	String.table.find = plume.obj.luaMacro("find", function (args)
		local s, pattern  = plume.shiftArgs(String, args)
		local pattern = tostring(pattern)

		if not args.table.rich then
			pattern = pattern:gsub("[%(%)%.%%%+%-%*%?%[%]%^%$]", "%%%1")
		end

		return s:match(pattern) or plume.empty
	end)
	String.table.contains = plume.obj.luaMacro("contains", function (args)
		local s, pattern  = plume.shiftArgs(String, args)
		local pattern = tostring(pattern)

		if not args.table.rich then
			pattern = pattern:gsub("[%(%)%.%%%+%-%*%?%[%]%^%$]", "%%%1")
		end

		if s:match(pattern) then
			return true
		else
			return false
		end
	end)
	String.table.startsWidth = plume.obj.luaMacro("startsWidth", function (args)
		local s, pattern  = plume.shiftArgs(String, args)
		local pattern = tostring(pattern)

		if not args.table.rich then
			pattern = pattern:gsub("[%(%)%.%%%+%-%*%?%[%]%^%$]", "%%%1")
		end

		if s:match("^"..pattern) then
			return true
		else
			return false
		end
	end)
	String.table.endsWidth = plume.obj.luaMacro("endsWidth", function (args)
		local s, pattern  = plume.shiftArgs(String, args)
		local pattern = tostring(pattern)

		if not args.table.rich then
			pattern = pattern:gsub("[%(%)%.%%%+%-%*%?%[%]%^%$]", "%%%1")
		end

		if s:match(pattern.."$") then
			return true
		else
			return false
		end
	end)
	String.table.count = plume.obj.luaMacro("count", function (args)
		local s, pattern  = plume.shiftArgs(String, args)
		local pattern = tostring(pattern)

		if not args.table.rich then
			pattern = pattern:gsub("[%(%)%.%%%+%-%*%?%[%]%^%$]", "%%%1")
		end

		local count = 0
		for x in s:gmatch(pattern) do
			count = count + 1
		end

		return count
	end)

	-- table making
	String.table.split = plume.obj.luaMacro("split", function (args)
		local s = plume.shiftArgs(String, args)
		local sep = args.table.sep or " "
		local t = plume.obj.table(0, 0)

		if not args.table.rich then
			sep = sep:gsub("[%(%)%.%%%+%-%*%?%[%]%^%$]", "%%%1")
		end

		local pos = 1
		for sub, _sep in s:gmatch('(.-)('..sep..")") do
			table.insert(t.table, sub)
			table.insert(t.keys, #t.table)
			pos = pos + #sub + #_sep
		end

		if pos <= #s then
			table.insert(t.table, s:sub(pos, -1))
			table.insert(t.keys, #t.table)
		end

		return t
	end)
	String.table.lines = plume.obj.luaMacro("lines", function (args)
		local s = plume.shiftArgs(String, args)
		local t = plume.obj.table(0, 0)

		local pos = 1
		for sub in s:gmatch('(.-)\n') do
			table.insert(t.table, sub)
			table.insert(t.keys, #t.table)
			pos = pos + #sub + 1
		end

		if pos <= #s then
			table.insert(t.table, s:sub(pos, -1))
			table.insert(t.keys, #t.table)
		end

		return t
	end)
	String.table.findAll = plume.obj.luaMacro("findAll", function (args)
		local s, pattern  = plume.shiftArgs(String, args)
		local pattern = tostring(pattern)
		local sub     = tostring(sub)

		if not args.table.rich then
			pattern = pattern:gsub("[%(%)%.%%%+%-%*%?%[%]%^%$]", "%%%1")
		end

		local t = plume.obj.table(0, 0)

		for sub in s:gmatch(pattern) do
			table.insert(t.table, sub)
			table.insert(t.keys, #t.table)
		end

		return t
	end)
	String.table.partition = plume.obj.luaMacro("partition", function (args)
		local s, pattern  = plume.shiftArgs(String, args)
		local pattern = tostring(pattern)

		if not args.table.rich then
			pattern = pattern:gsub("[%(%)%.%%%+%-%*%?%[%]%^%$]", "%%%1")
		end

		local t = plume.obj.table(3, 0)
		t.keys = {1, 2, 3}
		t.table[1], t.table[2], t.table[3] = s:match("(.-)("..pattern..")(.+)")

		return t
	end)

	plume.std.String = String
end
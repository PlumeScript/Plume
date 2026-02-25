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
	String.table.upper = {
		method =function (s)
			return true, string.upper(s)
		end
	}
	String.table.lower = {
		method =function (s)
			return true, string.lower(s)
		end
	}
	String.table.replace = {
		checkArgs = {
			checkTypes = {"string", "string", "string"},
			signature = "string s, string pattern, string sub, bool rich: $false",
			named={self=true, rich=true},
			args=3
		},
		method = function (s, pattern, sub, options)
			if not options.table.rich then
				pattern = pattern:gsub("[%(%)%.%%%+%-%*%?%[%]%^%$]", "%%%1")
				sub     = sub:gsub("%%", "%%%%")
			end

			return true, s:gsub(pattern, sub)
		end
	}

	-- Tests
	String.table.isNumber = {
		checkArgs = {
			checkTypes = {"string"},
			signature = "string s",
			named={self=true},
			args=1
		},
		method = function (s)
			if tonumber(s) then
				return true, true
			else
				return true, false
			end
		end
	}

	-- Normalization
	String.table.trim = {
		checkArgs = {
			checkTypes = {"string"},
			signature = "string s",
			named={self=true},
			args=1
		},
		method = function (s)
			return true, s:gsub('^%s*', ''):gsub('%s*$', '')
		end
	}
	String.table.rtrim = {
		checkArgs = {
			checkTypes = {"string"},
			signature = "string s",
			named={self=true},
			args=1
		},
		method = function (s)
			return true, s:gsub('^%s*', '')
		end
	}
	String.table.ltrim = {
		checkArgs = {
			checkTypes = {"string"},
			signature = "string s",
			named={self=true},
			args=1
		},
		method = function (s)
			return true, s:gsub('%s*$', '')
		end
	}
	String.table.collapse = {
		checkArgs = {
			checkTypes = {"string"},
			signature = "string s",
			named={self=true},
			args=1
		},
		method = function (s)
			return true, s:gsub('%s+', ' ')
		end
	}
	String.table.dedent = {
		checkArgs = {
			checkTypes = {"string"},
			signature = "string s",
			named={self=true},
			args=1
		},
		method = function (s)
			local firstIndent = s:match('^%s+')
			return true, s:gsub('^'..firstIndent, ''):gsub('\n'..firstIndent, '\n')
		end
	}
	String.table.indent = {
		checkArgs = {
			checkTypes = {"string", sep="string"},
			signature = "string s, string sep: \t",
			named={self=true},
			args=1
		},
		method = function (s, options)
			local sep = options.table.sep or "\t"
			return true, sep..s:gsub('\n', '\n'..sep)
		end
	}

	-- search
	String.table.find = {
		checkArgs = {
			checkTypes = {"string", "string"},
			signature = "string s, string pattern, bool rich: $false",
			named={self=true, rich=true},
			args=2
		},
		method = function (s, pattern, options)
			if not options.table.rich then
				pattern = pattern:gsub("[%(%)%.%%%+%-%*%?%[%]%^%$]", "%%%1")
			end

			return true, s:match(pattern) or plume.empty
		end
	}
	String.table.contains = {
		checkArgs = {
			checkTypes = {"string", "string"},
			signature = "string s, string pattern, bool rich: $false",
			named={self=true, rich=true},
			args=2
		},
		method = function (s, pattern, options)
			if not options.table.rich then
				pattern = pattern:gsub("[%(%)%.%%%+%-%*%?%[%]%^%$]", "%%%1")
			end

			if s:match(pattern) then
				return true, true
			else
				return true, false
			end
		end
	}
	String.table.startsWidth = {
		checkArgs = {
			checkTypes = {"string", "string"},
			signature = "string s, string pattern, bool rich: $false",
			named={self=true, rich=true},
			args=2
		},
		method = function (s, pattern, options)
			if not options.table.rich then
				pattern = pattern:gsub("[%(%)%.%%%+%-%*%?%[%]%^%$]", "%%%1")
			end

			if s:match("^"..pattern) then
				return true, true
			else
				return true, false
			end
		end
	}
	String.table.endsWidth = {
		checkArgs = {
			checkTypes = {"string", "string"},
			signature = "string s, string pattern, bool rich: $false",
			named={self=true, rich=true},
			args=2
		},
		method = function (s, pattern, options)
			if not options.table.rich then
				pattern = pattern:gsub("[%(%)%.%%%+%-%*%?%[%]%^%$]", "%%%1")
			end

			if s:match(pattern.."$") then
				return true, true
			else
				return true, false
			end
		end
	}
	String.table.count = {
		checkArgs = {
			checkTypes = {"string", "string"},
			signature = "string s, string pattern, bool rich: $false",
			named={self=true, rich=true},
			args=2
		},
		method = function (s, pattern, options)
			if not options.table.rich then
				pattern = pattern:gsub("[%(%)%.%%%+%-%*%?%[%]%^%$]", "%%%1")
			end

			local count = 0
			for x in s:gmatch(pattern) do
				count = count + 1
			end

			return true, count
		end
	}

	-- table making
	String.table.split = {
		checkArgs = {
			checkTypes = {"string", sep="string"},
			signature = "string s, string sep: \\s, bool rich: $false",
			named={self=true, rich=true},
			args=1
		},
		method = function (s, options)
			local sep = options.table.sep or " "
			local t = plume.obj.table(0, 0)

			if not options.table.rich then
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

			return true, t
		end
	}
	String.table.lines = {
		checkArgs = {
			checkTypes = {"string"},
			signature = "string s",
			named={self=true, rich=true},
			args=1
		},
		method = function (s)
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

			return true, t
		end
	}
	String.table.findAll = {
		checkArgs = {
			checkTypes = {"string", "string"},
			signature = "string s, string pattern, bool rich: $false",
			named={self=true, rich=true},
			args=2
		},
		method = function (s, pattern, options)
			local pattern = tostring(pattern)
			local sub     = tostring(sub)

			if not options.table.rich then
				pattern = pattern:gsub("[%(%)%.%%%+%-%*%?%[%]%^%$]", "%%%1")
			end

			local t = plume.obj.table(0, 0)

			for sub in s:gmatch(pattern) do
				table.insert(t.table, sub)
				table.insert(t.keys, #t.table)
			end

			return true, t
		end
	}
	String.table.partition = {
		checkArgs = {
			checkTypes = {"string", "string"},
			signature = "string s, string pattern, bool rich: $false",
			named={self=true, rich=true},
			args=2
		},
		method = function (s, pattern, options)
			if not options.table.rich then
				pattern = pattern:gsub("[%(%)%.%%%+%-%*%?%[%]%^%$]", "%%%1")
			end

			local t = plume.obj.table(3, 0)
			t.keys = {1, 2, 3}
			t.table[1], t.table[2], t.table[3] = s:match("(.-)("..pattern..")(.+)")

			return true, t
		end
	}

	plume.std.String = String
end
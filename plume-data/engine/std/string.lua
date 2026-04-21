--[[
This file is part of Plume🪶

Copyright © Erwan Barbedor
Licensed under the MIT License — see LICENSE for details.
]]

return function (plume)
	local String = plume.obj.table (0, 0)

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

	local function replaceUpdate(context)
		local s       = context.string
		local pos     = context.pos
		local pattern = context.pattern
		local acc     = context.acc

		local bpos, epos = s:sub(pos, -1):find(pattern)

		if bpos then
			context.PLUME_CALLBACK = context.macro
			table.insert(acc, s:sub(pos, pos+bpos-2))
			context.PLUME_CALLBACK_ARGS = {s:sub(pos+bpos-1, pos+epos-1)}
			context.pos = context.pos+epos
		else
			context.PLUME_CALLBACK = nil
			table.insert(acc, s:sub(pos, -1))
			context.pos = #s+1
			context.RETURN_VALUE = table.concat(acc)
		end
		return true
	end

	local function replaceNext(context, value)
		local t = type(value) == "table" and value.type or type(value)
		if t ~= "string" and t ~= "number" and t ~= "empty" then
			return false, string.format("Macro sub for `String.replace` must return a 'string' or a 'number', not a '%s'.", t)
		end

		if (type(value) ~= "table" or value.type ~= "empty") then
			table.insert(context.acc, value)
		end
		return true
	end

	String.table.replace = {
		checkArgs = {
			checkTypes = {"string", "string", {"string", "macro"}},
			signature = "string s, string pattern, string sub, bool rich: $false",
			named={self=true, rich=true},
			args=3
		},
		method = function (s, pattern, sub, options)
			if not options.table.rich then
				pattern = pattern:gsub("[%(%)%.%%%+%-%*%?%[%]%^%$]", "%%%1")
				if type(sub) == "string" then
					sub = sub:gsub("%%", "%%%%")
				end
			end

			if type(sub) ~= "string" then
				if sub.positionalParamCount ~= 1 then
					return false, string.format("Macro sub for `String.replace` must take exactly '1' argument, not '%i'.", sub.positionalParamCount)
				end

				local context = {
					type         = "hostContext",
					string       = s,
					pattern      = pattern,
					pos          = 1,
					macro        = sub,
					acc          = {},
					HOST_UPDATE  = replaceUpdate,
					HOST_NEXT    = replaceNext
				}
				return true, context, true
			end

			return true, (s:gsub(pattern, sub))
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
			return true, (s:gsub('^%s*', ''):gsub('%s*$', ''))
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
			return true, (s:gsub('^%s*', ''))
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
			return true, (s:gsub('%s*$', ''))
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
			return true, (s:gsub('%s+', ' '))
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
			return true, (s:gsub('^'..firstIndent, ''):gsub('\n'..firstIndent, '\n'))
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

			return true, (s:match(pattern) or plume.empty)
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

	String.table.rep = {
		checkArgs = {
			checkTypes = {"string", "string"},
			signature = "string s, number count, string sep: $empty",
			named={self=true, sep=true},
			args=2
		},
		method = function (s, count, options)
			local sep = options.table.sep or ""
			count = tonumber(count)
			local result = {}
			for i=1, count do
				table.insert(result, s)
				if i<count then
					table.insert(result, sep)
				end
			end

			return true, table.concat(result)
		end
	}

	String.table.sub = {
		checkArgs = {
			checkTypes = {"string", "number", "number"},
			signature = "string s, number start, number end",
			named={self=true, sep=true},
			args=3
		},
		method = function (s, spos, epos)
			if epos == 1 then
				epos = #s
			end

			return true, s:sub(spos, epos)
		end
	}

	plume.std.String = String
end
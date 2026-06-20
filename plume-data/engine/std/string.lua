--[[
This file is part of Plume🪶

Copyright © Erwan Barbedor
Licensed under the MIT License — see LICENSE for details.
]]

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

plume.std.String = plume.obj.quickTable {

	-- Manipulation
	upper = plume.obj.luaMacro("upper", function (args)
		--!override-self-plume.std.String
		--!signature string s
		return true, string.upper(s)
	end),
	lower = plume.obj.luaMacro("lower", function (args)
		--!override-self-plume.std.String
		--!signature string s
		return true, string.lower(s)
	end),

	replace = plume.obj.luaMacro("replace", function (args)
		--!override-self-plume.std.String
		--!signature string s, string pattern, string|macro sub, ?rich
		if not rich then
			pattern = pattern:gsub("[%(%)%.%%%+%-%*%?%[%]%^%$]", "%%%1")
			if type(sub) == "string" then
				sub = sub:gsub("%%", "%%%%")
			end
		end

		if type(sub) ~= "string" then
			-- In case of closure - we should have an api for that
			local positionalParamCount = sub.positionalParamCount or sub.macro.positionalParamCount
			if positionalParamCount ~= 1 then
				return false, string.format(
					"Macro sub for `String.replace` must take exactly '1' argument, not '%i'.",
					positionalParamCount
				)
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
	end),

	-- Tests
	isNumber = plume.obj.luaMacro("isNumber", function (args)
		--!override-self-plume.std.String
		--!signature string s
		if tonumber(s) then
			return true, true
		else
			return true, false
		end
	end),

	-- Normalization
	trim = plume.obj.luaMacro("trim", function (args)
		--!override-self-plume.std.String
		--!signature string s
		return true, (s:gsub('^%s*', ''):gsub('%s*$', ''))
	end),
	rtrim = plume.obj.luaMacro("rtrim", function (args)
		--!override-self-plume.std.String
		--!signature string s
		return true, (s:gsub('%s*$', ''))
	end),
	ltrim = plume.obj.luaMacro("ltrim", function (args)
		--!override-self-plume.std.String
		--!signature string s
		return true, (s:gsub('^%s*', ''))
	end),
	collapse = plume.obj.luaMacro("collapse", function (args)
		--!override-self-plume.std.String
		--!signature string s
		return true, (s:gsub('%s+', ' '))
	end),
	dedent = plume.obj.luaMacro("dedent", function (args)
		--!override-self-plume.std.String
		--!signature string s
		local firstIndent = s:match('^%s+')
		return true, (s:gsub('^'..firstIndent, ''):gsub('\n'..firstIndent, '\n'))
	end),
	indent = plume.obj.luaMacro("indent", function (args)
		--!override-self-plume.std.String
		--!signature string s, string sep:\t
		return true, sep..s:gsub('\n', '\n'..sep)
	end),

	-- search
	find = plume.obj.luaMacro("find", function (args)
		--!override-self-plume.std.String
		--!signature string s, string pattern, ?rich
		if not rich then
			pattern = pattern:gsub("[%(%)%.%%%+%-%*%?%[%]%^%$]", "%%%1")
		end

		return true, (s:match(pattern) or plume.empty)
	end),
	contains = plume.obj.luaMacro("contains", function (args)
		--!override-self-plume.std.String
		--!signature string s, string pattern, ?rich
		if not rich then
			pattern = pattern:gsub("[%(%)%.%%%+%-%*%?%[%]%^%$]", "%%%1")
		end

		if s:match(pattern) then
			return true, true
		else
			return true, false
		end
	end),
	startsWith = plume.obj.luaMacro("startsWith", function (args)
		--!override-self-plume.std.String
		--!signature string s, string pattern, ?rich
		if not rich then
			pattern = pattern:gsub("[%(%)%.%%%+%-%*%?%[%]%^%$]", "%%%1")
		end

		if s:match("^"..pattern) then
			return true, true
		else
			return true, false
		end
	end),
	endsWith = plume.obj.luaMacro("endsWith", function (args)
		--!override-self-plume.std.String
		--!signature string s, string pattern, ?rich
		if not rich then
			pattern = pattern:gsub("[%(%)%.%%%+%-%*%?%[%]%^%$]", "%%%1")
		end

		if s:match(pattern.."$") then
			return true, true
		else
			return true, false
		end
	end),
	count = plume.obj.luaMacro("count", function (args)
		--!override-self-plume.std.String
		--!signature string s, string pattern, ?rich
		if not rich then
			pattern = pattern:gsub("[%(%)%.%%%+%-%*%?%[%]%^%$]", "%%%1")
		end

		local count = 0
		for _ in s:gmatch(pattern) do
			count = count + 1
		end

		return true, count
	end),

	-- table making
	split = plume.obj.luaMacro("split", function (args)
		--!override-self-plume.std.String
		--!signature string s, string sep:\s, ?rich
		local t = plume.obj.table(0, 0)

		if not rich then
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
	end),
	lines = plume.obj.luaMacro("lines", function (args)
		--!override-self-plume.std.String
		--!signature string s
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
	end),
	findAll = plume.obj.luaMacro("findAll", function (args)
		--!override-self-plume.std.String
		--!signature string s, string pattern, ?rich

		if not rich then
			pattern = pattern:gsub("[%(%)%.%%%+%-%*%?%[%]%^%$]", "%%%1")
		end

		local t = plume.obj.table(0, 0)

		for sub in s:gmatch(pattern) do
			table.insert(t.table, sub)
			table.insert(t.keys, #t.table)
		end

		return true, t
	end),
	partition = plume.obj.luaMacro("partition", function (args)
		--!override-self-plume.std.String
		--!signature string s, string pattern, ?rich
		if not rich then
			pattern = pattern:gsub("[%(%)%.%%%+%-%*%?%[%]%^%$]", "%%%1")
		end

		local t = plume.obj.table(3, 0)
		t.keys = {1, 2, 3}
		t.table[1], t.table[2], t.table[3] = s:match("(.-)("..pattern..")(.+)")

		return true, t
	end),

	rep = plume.obj.luaMacro("rep", function (args)
		--!override-self-plume.std.String
		--!signature string s, number count, string sep:$empty
		count = tonumber(count)
		local result = {}
		for i=1, count do
			table.insert(result, s)
			if i<count then
				table.insert(result, sep)
			end
		end

		return true, table.concat(result)
	end),

	sub = plume.obj.luaMacro("sub", function (args)
		--!override-self-plume.std.String
		--!signature string s, number startpos, number endpos
		return true, s:sub(startpos, endpos)
	end)
}
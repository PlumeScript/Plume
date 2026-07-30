--[[
This file is part of Plume🪶

Copyright © Erwan Barbedor
Licensed under the MIT License — see LICENSE for details.
]]

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

	replace = plume.obj.luaMacro("replace", function (args, vm, _, self)
		--!override-self-plume.std.String
		--!signature string s, string pattern, string|macro sub, ?rich
		if not rich then
			pattern = pattern:gsub("[%(%)%.%%%+%-%*%?%[%]%^%$]", "%%%1")
			if type(sub) == "string" then
				sub = sub:gsub("%%", "%%%%")
			end
		end

		if type(sub) == "string" then
			return true, (s:gsub(pattern, sub))
		else
			-- In case of closure - we should have an api for that
			local positionalParamCount = sub.positionalParamCount or sub.macro.positionalParamCount
			if positionalParamCount ~= 1 then
				return false, string.format(
					"Macro sub for `String.replace` must take exactly '1' argument, not '%i'.",
					positionalParamCount
				)
			end

			local success = true
			local errmsg, result, callvmerrip
			s = s:gsub(pattern, function (match)
				if not success then
					return
				end

				--!vmcall
				success, result, callvmerrip = sub(match)

				-- Type check
				if success then
					local t = type(result) == "table" and result.type or type(result)
					if t == "fragment" then
						result = plume.makeFragment(result)
					elseif t ~= "string" and t ~= "number" and t ~= "empty" then
						success = false
						result = string.format("Macro sub for `String.replace` must return a 'string' or a 'number', not a '%s'.", t)
					end
				end

				if success then
					return result
				else
					vm.ip = callvmerrip
					errmsg = result
				end
			end)

			return success, errmsg or s
		end
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
			t:addItem(sub)
			pos = pos + #sub + #_sep
		end

		if pos <= #s then
			t:addItem(s:sub(pos, -1))
		end

		return true, t
	end),
	lines = plume.obj.luaMacro("lines", function (args)
		--!override-self-plume.std.String
		--!signature string s
		local t = plume.obj.table(0, 0)

		local pos = 1
		for sub in s:gmatch('(.-)\n') do
			t:addItem(sub)
			pos = pos + #sub + 1
		end

		if pos <= #s then
			t:addItem(s:sub(pos, -1))
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
			t:addItem(sub)
		end

		return true, t
	end),
	partition = plume.obj.luaMacro("partition", function (args)
		--!override-self-plume.std.String
		--!signature string s, string pattern, ?rich
		if not rich then
			pattern = pattern:gsub("[%(%)%.%%%+%-%*%?%[%]%^%$]", "%%%1")
		end

		local t = plume.obj.quickTable({s:match("(.-)("..pattern..")(.+)")})
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
		--!signature string s, number startpos, [number endpos]
		if not endpos then
			endpos = startpos
		end
		return true, s:sub(startpos, endpos)
	end)
}

plume.std.String.name = "String"
plume.std.String:setMetaItem('readonly', true)
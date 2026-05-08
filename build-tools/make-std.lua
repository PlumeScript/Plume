--[[
This file is part of Plume🪶

Copyright © Erwan Barbedor
Licensed under the MIT License — see LICENSE for details.
]]

-- Create std.lua by reading std/* and add type checking

local template = [=[
--[[
This file is part of Plume🪶

Copyright © Erwan Barbedor
Licensed under the MIT License — see LICENSE for details.
]]

return function(plume)
	%s
end
]=]

local function process(f)
	f = f:gsub('%-%-%[%[.-%]%]', '') -- remove license

	f = f:gsub('%"([^"]+)%", function %(args%)\n(%s*)%-%-!signature ([^\n]+)', function(name, indent, signature)
		local postionalArgsName = {}
		local optnPositionalArgs = {}
		local optnPositionalArgsCount = 0
		local allArgsName = {}
		local argsType = {}
		for t, n in signature:gmatch('(%S+) (%S+)') do
			n = n:gsub('%]$', '')
			if t:match('^%[') then
				optnPositionalArgs[n] = true
				optnPositionalArgsCount = optnPositionalArgsCount+1
			end
			t = t:gsub('^%[', '')
			table.insert(postionalArgsName, n)
			table.insert(allArgsName, n)
			if t ~= "any" then
				argsType[n] = t
			end
		end

		local checks = {"\n------------\n-- CHECKS --\n------------\n"}
			table.insert(checks, 'local __name      = "' .. name .. '"\n')
			table.insert(checks, 'local __signature = "' .. signature .. '"\n')
			table.insert(checks, 'local __s, __e')
			if #postionalArgsName > 0 then
				local posList = table.concat(postionalArgsName, ", ")
				table.insert(checks, string.format(', %s\n', posList))
				table.insert(checks,string.format(
					'__s, __e, %s = plume.stdUnpackPositional(args, %s, %s, __name, __signature)\n',
					posList, #postionalArgsName-optnPositionalArgsCount, #postionalArgsName
				))
			else
				table.insert(checks, '__s, __e = plume.stdUnpackPositional(args, 0, 0, __name, __signature)\n')
			end

			for _, argName in ipairs(allArgsName) do
				local expected = argsType[argName]
				if expected then
					if optnPositionalArgs[argName] then
						table.insert(checks, string.format(
							'if __s and %s then __s, __e = plume.stdCheckType(%s, "%s", "%s", __name, __signature) end\n',
							argName, argName, expected, argName
						))
					else
						table.insert(checks, string.format(
							'if __s then __s, __e = plume.stdCheckType(%s, "%s", "%s", __name, __signature) end\n',
							argName, expected, argName
						))
					end
				end
			end

			table.insert(checks, 'if not __s then return false, __e end\n')

		table.insert(checks, '------------')
		checks = (table.concat(checks):gsub('\n', '\n'..indent))

		return string.format('"%s", function (args)%s', name, checks)
	end)

	return f
end

local lfs = require "lfs"

local result = {}

for filename in lfs.dir("plume-data/engine/std") do
	if filename:match('%.lua$') then
		local file = io.open("plume-data/engine/std/"..filename)
		local content = file:read("*a")
		file:close()

		if not content:match("return function %(plume%)") then
			table.insert(result, process(content))
		end
	end
end



result = string.format(template, (table.concat(result):gsub('\n', '\n\t')))
local out = io.open("plume-data/engine/std.lua", "w")
	out:write(result)
out:close()
--[[
This file is part of Plume🪶

Copyright © Erwan Barbedor
Licensed under the MIT License — see LICENSE for details.
]]

return function(plume)

	local function toint(x)
		local n = tonumber(x)
		return n and n == math.floor(n) and n
	end

	local function isShortTable(t)
		local l = 0
		for k, v in pairs(t.table) do
			if type(k) == "table" or type(v) == "table" then
				return false
			end
			if type(k) ~= "number" then
				l = l + #tostring(k)
			end
			l = l + #tostring(v)
		end

		return l < 80
	end

	local function reprTable(t, acc, pretty, indent)
		acc[t] = true

		local result = {}
		local ordered = true
		local lastIndex = 0

		local itemsCount = 0
		local valueCount = 0

		pretty = pretty and not isShortTable(t)
		for _, key in ipairs(t.keys) do
			local value = plume.repr(t.table[key], acc, pretty, indent + 1)
			local index = toint(key)
			if index then
				itemsCount = itemsCount + 1
				if ordered then
					if index < lastIndex or index > lastIndex + 2 then
						ordered = false
					else
						for _ = 1, index - lastIndex - 1 do
							table.insert(result, "empty")
						end
						lastIndex = index
					end
				end

				if ordered then
					if pretty then
						value = "- " .. value
					end
					table.insert(result, value)
				else

					table.insert(result, string.format("%s: %s", key, value))
				end
			else
				valueCount = valueCount + 1
				local rkey = plume.repr(key, acc)
				table.insert(result, string.format("%s: %s", rkey, value))
			end
		end

		if pretty then
			local template
			if indent == 0 then
				template = "%s%s\n%s"
			else
				template = "do\n%s%s\n%send"
			end

			return string.format(template,
				("  "):rep(indent),
				table.concat(result, "\n" .. ("  "):rep(indent)),
				("  "):rep(indent - 1)
			)
		else
			local prefix = "$Table"
			local inline = itemsCount > 1 or valueCount > 0
			if inline then
				prefix = ""
			end
			return string.format("%s(%s)", prefix, table.concat(result, ", "))
		end
	end

	local function reprObj(obj, pretty, indent)
		indent = indent or 0
		
		if type(obj) == "string" then
			obj = obj:gsub('\\', '\\\\')
			obj = obj:gsub('%$', '\\$')
		end

		if type(obj) == "string" and pretty and #obj > 80 then
			local result = {"do"}
			for i = 1, #obj / 80 + 1 do
				local line = obj:sub((i - 1) * 80 + 1, i * 80)
				line = line:gsub('^ ', '\\s'):gsub(' $', '\\s')
				table.insert(result, line)
			end
			return table.concat(result, "\n" .. ("  "):rep(indent + 1)) .. "\n" .. ("  "):rep(indent) .. "end"
		else
			return tostring(obj)
		end
	end

	local function reprFragment(obj)
		local childs = {}
		for _, child in ipairs(obj) do
			table.insert(childs, plume.repr(child))
		end
		return "Fragment(" .. table.concat(childs, ",") .. ")"
	end

	function plume.repr(obj, acc, pretty, indent)
		acc = acc or {}
		indent = indent or 0
		if type(obj) ~= "table" then
			return reprObj(obj, pretty, indent)
		end

		local t = obj.type or "???"
		if t == "empty" then
			if indent == 0 then
				return "$empty"
			else
				return ""
			end
		elseif t == "boolean" then
			return "$" .. tostring(obj)
		elseif t == "luaMacro" or t == "stdMacro" or t == "macro" then
			return t .. "<" .. obj.name .. ">"
		elseif t == "closure" then
			return "macro<" .. (obj.macro.name or "???") .. ">"
		elseif t == "table" then
			if acc[obj] then
				return "$Table(...)"
			else
				return reprTable(obj, acc, pretty, indent)
			end
		elseif t == "context" then
			local values = {}
			for _, value in ipairs(obj.values) do
				table.insert(values, plume.repr(value))
			end
			return string.format("Context<%s>", table.concat(values, ", "))
		elseif t == "fragment" then
			return reprFragment(obj)
		else
			return t .. "Obj<" .. (t.name or "???") .. ">"
		end
	end

	function plume.reprOutput(obj)
		local t = type(obj) == "table" and obj.type or type(obj)
		if t == "string" then
			return obj
		elseif t == "number" or t == "bool" then
			return tostring(obj)
		elseif t == "empty" then
			return ""
		else
			return plume.repr(obj)
		end
	end

end
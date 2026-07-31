--[[
This file is part of Plume🪶

Copyright © Erwan Barbedor
Licensed under the MIT License — see LICENSE for details.
]]

function plume.stdUtils.copy(t, deep, nt)
	nt = nt or plume.obj.table(#t.table, #t.keys)

	for _, key in ipairs(t.keys) do
		local rawvalue = t.table[key]
		local value
		if deep and type(rawvalue) == "table" and rawvalue.type == "table" then
			if deep[rawvalue] then
				value = deep[rawvalue]
			else
				deep[rawvalue] = plume.obj.table(0, 0)
				value = plume.stdUtils.copy(rawvalue, deep, deep[rawvalue])
			end
		else
			value = rawvalue
		end

		nt:setItem(key, value)
	end
	nt.name = t.name
	nt.doc  = t.doc
	return nt
end

local function handleNegativeIndex(index, len)
	if index < 0 then
		index = index+1
		while index <= 0 do
			index = index + len
		end
	end

	return index
end

local function deepMerge(t1, t2, concatNumeric)
	local result = plume.stdUtils.copy(t1, {})
	for _, key in ipairs(t2.keys) do
		local v2 = t2.table[key]
		if tonumber(key) and concatNumeric then
			result:addItem(v2)
		else
			local v3
			if t1.table[key] then
				local v1 = t1.table[key]
				if type(v1) == "table" and v1.type == "table" and type(v1) == "table" and v1.type == "table" then
					v3 = deepMerge(v1, v2)
				else
					v3 = v2
				end
			else
				v3 = v2
			end

			result:setItem(key, v3)
		end
	end

	return result
end

local function expandInto(result, t, deep)
	for _, value in ipairs(t.table) do
		if deep and type(value) == "table" and value.type == "table" then
			expandInto(result, value, deep)
		else
			result:addItem(value)
		end
	end
end

plume.std.Table = plume.obj.quickTable{
	remove = plume.obj.luaMacro("remove", function(args)
		--!signature table t, [number index]
		index = (type(index) == "number" and index) or #t.table

		for keyIndex, keyValue in ipairs(t.keys) do
			if keyValue == index then
				table.remove(t.keys, keyIndex)

				if tonumber(keyValue) then
					for shiftedKeyIndex, shiftedKeyValue in ipairs(t.keys) do
						if tonumber(shiftedKeyValue) and shiftedKeyValue > keyValue then
							t.keys[shiftedKeyIndex] = shiftedKeyValue-1
						end
					end
				end
				break
			end
		end

		return true, table.remove(t.table, index)
	end),
	append = plume.obj.luaMacro("append", function(args)
		--!signature table t, (any item)
		table.insert(t.table, item)
		table.insert(t.keys, #t.table)
		return true
	end),
	join = plume.obj.luaMacro("join", function(args)
		--!signature string sep:$empty, (string ...items)
		if sep == plume.obj.empty then
			sep = ""
		end

		local args = args.table
		if args and #args == 1 and type(args[1]) == "table" and args[1].type == "table" then
			return false, plume.error.joinErrorHint()
		end

		for i, value in ipairs(args) do
			if type(value) == "table" and (value.type == "fragment" or value.meta.table.fragment) then
				args[i] = plume.callForceFragment(vm, value)
			elseif type(value) ~= "number" and type(value) ~= "string" then
				return false, plume.error.wrongArgTypeStd(i, "join", type(value), "string", "$table.join(string ...items)")
			end
		end

		return pcall(table.concat, args, sep)
	end),
	removeKey = plume.obj.luaMacro("removeKey", function(args)
		--!signature table t, any key
		key = tonumber(key) or key
		local index = 0
		for k, v in ipairs(t.keys) do
			if v == key then
				index = k
				break
			end
		end

		if index == 0 then
			return false, plume.error.cannotRemoveNotfoundKey(key)
		end

		t.table[key] = nil
		table.remove(t.keys, index)
		return true
	end),
	hasKey = plume.obj.luaMacro("hasKey", function(args)
		--!signature table t, any key
		key = tonumber(key) or key
		for _, v in ipairs(t.keys) do
			if v == key then
				return true, true
			end
		end

		return true, false
	end),
	find = plume.obj.luaMacro("find", function(args)
		--!signature table t, any x
		for _, v in ipairs(t.keys) do
			if t.table[v] == x then
				return true, v
			end
		end
		return true, nil
	end),
	findAll = plume.obj.luaMacro("findAll", function(args)
		--!signature table t, any x
		local result = plume.obj.table(0, 0)
		for _, v in ipairs(t.keys) do
			if t.table[v] == x then
				result:addItem(v)
			end
		end

		return true, result
	end),
	count = plume.obj.luaMacro("count", function(args)
		--!signature table t, ?named
		if named then
			local count = 0
			for _, v in ipairs(t.keys) do
				if not tonumber(v) then
					count = count + 1
				end
			end
			return true, count
		else
			return true, #t.keys
		end
	end),
	entry = plume.obj.luaMacro("entry", function(args)
		--!signature table t, any index
		local key = t.keys[index]
		local result = plume.obj.table(2, 0)
		result:addItem(key)
		result:addItem(t.table[key])
		
		return true, result
	end),

	sort = plume.obj.luaMacro("sort", function(args, vm)
		--!signature table t, macro compare:

		for i, x in ipairs(t.table) do
			local _type = type(x) == "table" and x.type or type(x)
			if _type ~= "number" or not tonumber(x) then
				return false, string.format("Table element #%i type is '%s' instead of 'number',\nand therefore cannot be sorted.", i, _type)
			end
		end

		if compare and #t.table > 1 then
			-- In case of closure - we should have an api for that
			local positionalParamCount = compare.positionalParamCount or compare.macro.positionalParamCount
			if positionalParamCount ~= 2 then
				return false, string.format(
					"Macro compare for `Table.sort` must take exactly '2' arguments, not '%i'.",
					positionalParamCount
				)
			end

			local success = true
			local errmsg, result, callvmerrip
			table.sort(t.table, function(x, y)
				if not success then
					return
				end
				--!vmcall
				success, result, callvmerrip = compare(x, y)

				if success then
					return result
				else
					vm.ip = callvmerrip
					errmsg = result
				end
			end)

			return success, errmsg
		else
			table.sort(t.table)
			return true
		end
	end),

	copy = plume.obj.luaMacro("copy", function(args)
		--!signature table t
		return true, plume.stdUtils.copy(t)
	end),

	deepcopy = plume.obj.luaMacro("deepcopy", function(args)
		--!signature table t
		return true, plume.stdUtils.copy(t, {})
	end),

	sum = plume.obj.luaMacro("sum", function(args)
		--!signature (number ...items)

		if args.table and #args.table == 1 and type(args.table[1]) == "table" and args.table[1].type == "table" then
			return false, plume.error.sumErrorHint()
		end

		local r = 0
		for i, x in ipairs(args.table) do
			if not tonumber(x) then
				return false, plume.error.wrongArgTypeStd(i, "sum", type(x), "number", "$table.sum(number ...items)")
			end
			r = r + x
		end
		return true, r
	end),

	at = plume.obj.luaMacro("at", function(args)
		--!signature table t, number index, [number stop]

		index = handleNegativeIndex(index, #t.table)
		if stop then
			stop = handleNegativeIndex(stop, #t.table)
		end

		if stop then
			local result = plume.obj.table(stop - index + 1, 0)
			for i=index, stop do
				local value = t.table[i]
				if not value then
					return false, plume.error.unregisteredKey(t, index)
				end
				result:addItem(value)
			end
			return true, result
		else
			local value = t.table[index]
			if value then
				return true, value
			else
				return false, plume.error.unregisteredKey(t, index)
			end
		end
	end),

	setAt = plume.obj.luaMacro("setAt", function(args)
		--!signature table t, number index, any value
		index = handleNegativeIndex(index, #t.table)

		t:setItem(index, value)
		return true
	end),

	setMeta = plume.obj.luaMacro("setMeta", function(args)
		--!signature table t, table meta
		t.meta = meta
		return true
	end),
	getMeta = plume.obj.luaMacro("setMeta", function(args)
		--!signature table t
		if not t.meta then
			t.meta = plume.obj.table(0, 0)
		end

		return true, t.meta
	end),

	deepMerge = plume.obj.luaMacro("deepMerge", function(args)
		--!signature table t1, table t2, ?concatNumeric
		return true, deepMerge(t1, t2, concatNumeric)
	end),

	flatten = plume.obj.luaMacro("flatten", function(args)
		--!signature table t, ?deep
		local result = plume.obj.table(0, 0)

		for _, value in ipairs(t.table) do
			if type(value) == "table" and value.type == "table" then
				expandInto(result, value, deep)
			else
				result:addItem(value)
			end
		end

		return true, result
	end),

	materialize = plume.obj.luaMacro("materialize", function(args, vm)
		--!signature table t
		local result = plume.callForceFragment(vm, t)

		if type(result) == "table" and result.type == "table" then
			for _, key in ipairs(result.keys) do
				result.table[key] = plume.callForceFragment(vm, result.table[key])
			end
		end

		return true, result
	end)
}

plume.std.Table.meta = plume.obj.quickTable{
	validate = plume.obj.luaMacro ("call", function(args)
		--!signature any x
		local t = type(x) == "table" and x.type or  type(x)
		if t ~= "table" then
			return false, string.format("Cannot convert '%s' to a table.", t)
		else
			return true, x
		end
	end)
}

plume.std.Table.name = "Table"
plume.std.Table:setMetaItem('readonly', true)
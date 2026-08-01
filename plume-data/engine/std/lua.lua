--[[
This file is part of Plume🪶

Copyright © Erwan Barbedor
Licensed under the MIT License — see LICENSE for details.
]]
	
plume.std.print = plume.obj.luaMacro("print", function(args)
	local result = {}
	for _, x in ipairs(args.table) do
		table.insert(result, plume.repr(x, nil, args.table.pretty))
	end
	print(table.unpack(result))
	return true
end)

plume.std.help = plume.obj.luaMacro("help", function (args)
	--!signature callable|table m
	print(plume.makedoc(m))
	return true
end)

-- io
plume.std.write = plume.obj.luaMacro("write", function(args)
	--!signature string filename, string content, ?append
	return plume.stdio.write(filename, content, append)
end)

plume.std.read = plume.obj.luaMacro("read", function(args)
	--!signature string filename
	return plume.stdio.read(filename)
end)

plume.std.rawset = plume.obj.luaMacro("rawset", function(args)
	--!signature table obj, string key, any value

	if not obj.table[key] then
		table.insert(obj.keys, key)
	end
	obj.table[key] = value
	return true
end)

plume.std.repr = plume.obj.luaMacro("repr", function(args)
	--!signature any obj, ?pretty
	return true, plume.repr(obj, nil, pretty)
end)

plume.std.min = plume.obj.luaMacro("min", function(args)
	--!signature number ...numbers
	return true, math.min(unpack(args.table))
end)
plume.std.max = plume.obj.luaMacro("max", function(args)
	--!signature number ...numbers
	return true, math.max(unpack(args.table))
end)

plume.std.len = plume.obj.luaMacro("len", function(args)
	--!signature table|string x
	return true, type(x) == "table" and #x.table or #x
end)

plume.std.type = plume.obj.luaMacro("type", function(args)
	--!signature any x
	return true, type(x) == "table" and x.type or (type(x) == "cdata" and x.type) or type(x)
end)

plume.std.seq = plume.obj.luaMacro("seq", function(args, vm)
	--!signature number start, [number stop], [number step]

	local start = tonumber(args.table[1])
	local stop  = tonumber(args.table[2])
	local step  = tonumber(args.table[3] or 1)

	if not stop then
		stop = start
		start = 1
	end

	local result = {
		type = "stdIterator",
		start=start-step,
		stop=stop,
		step=step,
		flag = vm.flag.ITER_SEQ
	}

	return true, result
end)

plume.std.items = plume.obj.luaMacro("items", function(args, vm)
	--!signature table t, ?named

   local result = {
        type = "stdIterator",
        ref  = t,
        flag = vm.flag.ITER_ITEMS,
        named = named,
    }

	return true, result
end)

plume.std.enumerate = plume.obj.luaMacro("enumerate", function(args, vm)
	--!signature table t

   local result = {
        type = "stdIterator",
        ref = t,
        flag = vm.flag.ITER_ENUMS
    }

	return true, result
end)


plume.std.List = plume.obj.table(0, 0)
plume.std.List.meta = plume.obj.quickTable{
	call = plume.obj.luaMacro ("call", function(args)
		--!signature table t !meta:List
		local result = plume.obj.table(0, 0)
		for k, v in ipairs(t.table) do
			result:addItem(v)
		end
		return true, result
	end),
	validate = plume.obj.luaMacro ("validate", function(args)
		--!signature table t !meta:List
		for _, k in ipairs(t.keys) do
			if not tonumber(k) then
				return false, string.format("Received extra named argument '%s', but extra arguments must be positional.", k)
			end
		end

		return true, args
	end)
}

plume.std.Map = plume.obj.table(0, 0)
plume.std.Map.meta = plume.obj.quickTable{
	call = plume.obj.luaMacro ("call", function(args)
		--!signature table t !meta:Map
		local result = plume.obj.table(0, 0)
		for _, k in ipairs(t.keys) do
			if not tonumber(k) then
				result:setItem(k, t.table[k])
			end
		end
		return true, result
	end),
	validate = plume.obj.luaMacro ("validate", function(args)
		--!signature table t !meta:Map
		for _, k in ipairs(t.keys) do
			if tonumber(k) then
				return false, "Received an extra positional argument, but extra arguments must be named."
			end
		end

		return true, args
	end)
}

plume.std.lua = plume.obj.table(0, 0)

plume.std.lua:setItem("require", plume.obj.luaMacro("require", function(args, vm, fileID)
	local runtime = vm.runtime
	local firstFilename = runtime.files[1].name
	local lastFilename  = runtime.files[fileID].name

	local filename, searchPaths = plume.getFilenameFromPath(args.table[1], true, runtime, firstFilename, lastFilename)
	if filename then
		return true, dofile(filename)(plume) 
	else
		local msg = "Error: cannot open '" .. args.table[1] .. "'.\nPaths tried:\n\t" .. table.concat(searchPaths, '\n\t')
		return false, msg
	end
end))

plume.std.lua:setItem("eval", plume.obj.luaMacro("eval", function(args, vm)
	--!signature string code, [string filename], ?safe
	local success, result = load(code, filename)

	if success then
		success, result = pcall(success)
		if success then
			local t = type(result)
			if t == nil then
				result = plume.obj.empty
			elseif t ~= "string" and t ~= "number" then
				return false, string.format("The lua code returned  a '%s' object, that cannot be converted into Plume object.\n(i) For now, only `string`, `number` and `nil` return are supported.", t)
			end
		end
	end
	if safe then
		local safeResult = plume.obj.table(0, 2)
		safeResult:setItem("success", success)
		safeResult:setItem("result", result)
		return true, safeResult
	else
		return success, result
	end
end))


plume.std.attempt = plume.obj.table(0, 0)

plume.std.Context = plume.obj.luaMacro("Context", function(args)
	return true, plume.obj.context(args.table[1])
end)

-- Basic implementation, prone to memory leaks
plume.std.eval = plume.obj.luaMacro("eval", function(args, vm)
	--!signature string code, [string filename], ?safe

	local success, result, errip
	filename = filename or "<string>"

	-- compile
	local runtime = vm.runtime
	-- local success, result = plume.executeString(code, filename or "<string>", runtime, nil, nil, false)
	local chunk = plume.obj.macro(filename, runtime)
	success, result = pcall(plume.compileFile, code, filename, chunk, runtime)

	if success then
		-- prepare stack
		vm:_STACK_PUSH(vm.fileStack, chunk.fileID)
		vm:_STACK_PUSH(vm.recursiveStack, vm.ip+1)

		-- execute
		success, result, errip = plume.run(runtime, chunk)
		
		if success then
			-- clean stack
			vm:_STACK_POP(vm.mainStack)
		end
	end
	
	if safe then
		local safeResult = plume.obj.table(0, 2)
		safeResult:setItem("success", success)
		safeResult:setItem("result", result)
		return true, safeResult
	else
		return success, result
	end
end)
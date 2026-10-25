--[[
This file is part of Plume🪶

Copyright © Erwan Barbedor
Licensed under the MIT License — see LICENSE for details.
]]
	
plume.std.print = plume.obj.luaMacro("print", function(args)
	--!signature ...args
	local result = {}
	for _, x in ipairs(args.table) do
		local success, _, value = plume.stdCheckType(vm, x, "string", "", "", "")
		if not success then
			value = plume.repr(x, nil, args.table.pretty)
		end
		table.insert(result, value)
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
plume.std.write = plume.obj.luaMacro("write", function(args, vm, currentFile)
	--!signature string filename, string content, ?append
	filename = plume.resolveRelativePath(filename, vm:_GET_CURRENT_FILE().name)
	return plume.stdio.write(filename, content, append)
end)

plume.std.read = plume.obj.luaMacro("read", function(args, vm, currentFile)
	--!signature string filename
	filename = plume.resolveRelativePath(filename, vm:_GET_CURRENT_FILE().name)
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

plume.std.type = plume.obj.luaMacro("type", function(args, vm)
	--!signature any x
	x = plume.callForceFragment(vm, x)
	if vm.err then
		return false, vm.err
	end

	local result = type(x) == "table" and x.type or (type(x) == "cdata" and x.type) or type(x)
	if result == "closure" then
		result = "macro"
	end
	return true, result
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

	if step == 0 then
		return false, plume.error.seqCannotUseNulStep()
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

plume.std.lua:setItem("require", plume.obj.luaMacro("require", function(args, vm, currentFile)
	--!signature string filename
	local runtime = vm.runtime
	local firstFilename = runtime.files[1].name
	local lastFilename  = runtime.files[currentFile].name

	local filename, searchPaths = plume.getFilenameFromPath(filename, true, runtime, firstFilename, lastFilename)
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
			if t == "nil" then
				result = plume.obj.empty
			elseif t ~= "string" and t ~= "number" and t ~= "boolean" then
				return false, string.format("The lua code returned  a '%s' object, that cannot be converted into Plume object.\n(i) For now, only `string`, `number`, `boolean` and `nil` return are supported.", t)
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

plume.std.Context = plume.obj.luaMacro("Context", function(args, vm)
	--!signature [any x]
	if x then
		x = plume.callForceFragment(vm, x)
	end
	return true, plume.obj.context(x)
end)

plume.std.eval = plume.obj.luaMacro("eval", function(args, vm)
	--!signature string code, [string filename], ?safe

	local success, result, errip
	filename = filename or "<string>"

	-- compile
	local runtime = vm.runtime
	-- local success, result = plume.executeString(code, filename or "<string>", runtime, nil, nil, false)
	local chunk = plume.obj.macro(filename, runtime)
	-- noCache: the chunk cache is keyed by filename (file imports assume the
	-- same name implies the same source). Eval'd strings don't follow that —
	-- every call must compile its own code, even with the default `<string>`.
	success, result = pcall(plume.compileFile, code, filename, chunk, runtime, nil, {noCache = true})

	if success then
		-- prepare stack
		-- Return marker for the nested run's _RUN_END: must be vm.ip, exactly
		-- like _RUN_START does. _RUN_END (vm/run.lua) pops it and sets
		-- self.ip to it, and the caller's loop resumes one instruction after —
		-- so when eval is called from a safe-run boundary (e.g. `attempt`),
		-- vm.ip is the sops ip and the end jump propagates, terminating the
		-- safe run once the eval'd code returns (instead of resuming right
		-- after the sops header and re-executing the file, which overflowed
		-- the stack — issue #1291).
		-- A `+1` here was wrong in both cases: it skipped the caller's
		-- STORE_LOCAL after `let x = $eval(...)` (value never assigned, and
		-- in `$String($eval(...))` the outer macro was never loaded — issue
		-- #1292) and failed the dev-mode end-of-file final check.
		-- The fileStack entry is pushed by plume.run and popped by the eval'd
		-- chunk's RETURN_FILE: pushing it here as well leaked one entry per
		-- eval and corrupted `currentFile` for later read/write/import.
		vm:_STACK_PUSH(vm.recursiveStack, vm.ip)

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
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
	--!signature macro macro
	local name = macro.debugMacroName or macro.name
	local doc = macro.doc or ""
	print("macro " .. name .. "\n    " .. doc:gsub('\n', '\n    ') or "")
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

plume.std.List = plume.obj.table(0, 0)
plume.std.List.meta = plume.obj.quickTable{
	call = plume.obj.luaMacro ("call", function(args)
		--!signature table t !meta:List
		local result = plume.obj.table(0, 0)
		for k, v in ipairs(t.table) do
			table.insert(result.keys, k)
			table.insert(result.table, v)
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
				table.insert(result.keys, k)
				result.table[k] = t.table[k]
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

plume.std.lua.table.require =  plume.obj.luaMacro("require", function(args, runtime, fileID)
	local firstFilename = runtime.files[1].name
	local lastFilename  = runtime.files[fileID].name

	local filename, searchPaths = plume.getFilenameFromPath(args.table[1], true, runtime, firstFilename, lastFilename)
	if filename then
		return true, dofile(filename)(plume) 
	else
		msg = "Error: cannot open '" .. args.table[1] .. "'.\nPaths tried:\n\t" .. table.concat(searchPaths, '\n\t')
		return false, msg
	end
end)

plume.std.attempt = plume.obj.table(0, 0)

plume.std.Context = plume.obj.luaMacro("Context", function(args)
	return true, plume.obj.context(args.table[1])
end)
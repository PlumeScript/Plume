--[[
This file is part of Plume🪶

Copyright © Erwan Barbedor
Licensed under the MIT License — see LICENSE for details.
]]

return function(plume)
	
	
	plume.stdio = {}
	function plume.stdio.write(path, content, append)
		local mode = append and "a" or "w"
		local file = io.open(path, mode)
			if not file then
				return false, "Cannot write file '" .. path .. "'."
			end
			file:write(content)
		file:close()
		return true
	end
	
	function plume.stdio.read(path)
		local file = io.open(path)
			if not file then
				return false, "Cannot read file '" .. path .. "'."
			end
			local content = file:read("*a")
		file:close()
		return true, content
	end
	    
	plume.std.print = plume.obj.luaMacro("print", function(args)
	    local result = {}
	    for _, x in ipairs(args.table) do
	        table.insert(result, plume.repr(x, nil, args.table.pretty))
	    end
	    print(table.unpack(result))
	    return true
	end)
	
	plume.std.help = plume.obj.luaMacro("help", function (args)
	    ------------
	    -- CHECKS --
	    ------------
	    local __name      = "help"
	    local __signature = "macro macro"
	    local __s, __e, macro
	    __s, __e, macro = plume.stdUnpackPositional(args, 1, 1, __name, __signature)
	    if __s then __s, __e = plume.stdUnpackNamed(args, nil, __name, __signature) end
	    if __s then __s, __e = plume.stdCheckType(macro, "macro", "macro", __name, __signature) end
	    if not __s then return false, __e end
	    ------------
	    print("macro " .. (macro.debugMacroName or macro.name) .. "\n    " .. macro.doc:gsub('\n', '\n    ') or "")
	    return true
	end)
	
	-- io
	plume.std.write = plume.obj.luaMacro("write", function (args)
	    ------------
	    -- CHECKS --
	    ------------
	    local __name      = "write"
	    local __signature = "string filename, string content, ?append"
	    local __s, __e, filename, content
	    __s, __e, filename, content = plume.stdUnpackPositional(args, 2, 2, __name, __signature)
	    local append
	    if __s then __s, __e, append = plume.stdUnpackNamed(args, {append=true}, __name, __signature) end
	    if __s then __s, __e = plume.stdCheckType(filename, "string", "filename", __name, __signature) end
	    if __s then __s, __e = plume.stdCheckType(content, "string", "content", __name, __signature) end
	    if not __s then return false, __e end
	    ------------
	    return plume.stdio.write(filename, content, append)
	end)
	
	plume.std.read = plume.obj.luaMacro("read", function (args)
	    ------------
	    -- CHECKS --
	    ------------
	    local __name      = "read"
	    local __signature = "string filename"
	    local __s, __e, filename
	    __s, __e, filename = plume.stdUnpackPositional(args, 1, 1, __name, __signature)
	    if __s then __s, __e = plume.stdUnpackNamed(args, nil, __name, __signature) end
	    if __s then __s, __e = plume.stdCheckType(filename, "string", "filename", __name, __signature) end
	    if not __s then return false, __e end
	    ------------
	    return plume.stdio.read(filename)
	end)
	
	plume.std.rawset = plume.obj.luaMacro("rawset", function (args)
	    ------------
	    -- CHECKS --
	    ------------
	    local __name      = "rawset"
	    local __signature = "table obj, string key, any value"
	    local __s, __e, obj, key, value
	    __s, __e, obj, key, value = plume.stdUnpackPositional(args, 3, 3, __name, __signature)
	    if __s then __s, __e = plume.stdUnpackNamed(args, nil, __name, __signature) end
	    if __s then __s, __e = plume.stdCheckType(obj, "table", "obj", __name, __signature) end
	    if __s then __s, __e = plume.stdCheckType(key, "string", "key", __name, __signature) end
	    if not __s then return false, __e end
	    ------------
	
	    if not obj.table[key] then
	        table.insert(obj.keys, key)
	    end
	    obj.table[key] = value
	    return true
	end)
	
	plume.std.repr = plume.obj.luaMacro("repr", function (args)
	    ------------
	    -- CHECKS --
	    ------------
	    local __name      = "repr"
	    local __signature = "any obj, ?pretty"
	    local __s, __e, obj
	    __s, __e, obj = plume.stdUnpackPositional(args, 1, 1, __name, __signature)
	    local pretty
	    if __s then __s, __e, pretty = plume.stdUnpackNamed(args, {pretty=true}, __name, __signature) end
	    if not __s then return false, __e end
	    ------------
	    return true, plume.repr(obj, nil, pretty)
	end)
	
	plume.std.min = plume.obj.luaMacro("min", function (args)
	    ------------
	    -- CHECKS --
	    ------------
	    local __name      = "min"
	    local __signature = "number ...numbers"
	    local __s, __e = plume.stdUnpackPositional(args, 0, 0, __name, __signature)
	    if __s then __s, __e = plume.stdUnpackNamed(args, nil, __name, __signature) end
	    if not __s then return false, __e end
	    ------------
	    return true, math.min(unpack(args.table))
	end)
	plume.std.max = plume.obj.luaMacro("max", function (args)
	    ------------
	    -- CHECKS --
	    ------------
	    local __name      = "max"
	    local __signature = "number ...numbers"
	    local __s, __e = plume.stdUnpackPositional(args, 0, 0, __name, __signature)
	    if __s then __s, __e = plume.stdUnpackNamed(args, nil, __name, __signature) end
	    if not __s then return false, __e end
	    ------------
	    return true, math.max(unpack(args.table))
	end)
	
	plume.std.List = plume.obj.table(0, 0)
	plume.std.List.meta = plume.obj.quickTable{
	    call = plume.obj.luaMacro ("call", function(args)
	        local result = plume.obj.table(0, 0)
	        local t = args.table[1]
	        for k, v in ipairs(t.table) do
	            table.insert(result.keys, k)
	            table.insert(result.table, v)
	        end
	        return true, result
	    end),
	    validate = plume.obj.luaMacro ("validate", function(args)
	        local t = args.table[1]
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
	        local result = plume.obj.table(0, 0)
	        local t = args.table[1]
	        for _, k in ipairs(t.keys) do
	            if not tonumber(k) then
	                table.insert(result.keys, k)
	                result.table[k] = t.table[k]
	            end
	        end
	        return true, result
	    end),
	    validate = plume.obj.luaMacro ("validate", function(args)
	        local t = args.table[1]
	        for _, k in ipairs(t.keys) do
	            if tonumber(k) then
	                return false, "Received an extra positional argument, but extra arguments must be named."
	            end
	        end
	
	        return true, args
	    end)
	}
	
	plume.std.os = plume.obj.quickTable {
	    getEnv = plume.obj.luaMacro("getEnv", function (args)
	        ------------
	        -- CHECKS --
	        ------------
	        local __name      = "getEnv"
	        local __signature = "string name"
	        local __s, __e, name
	        __s, __e, name = plume.stdUnpackPositional(args, 1, 1, __name, __signature)
	        if __s then __s, __e = plume.stdUnpackNamed(args, nil, __name, __signature) end
	        if __s then __s, __e = plume.stdCheckType(name, "string", "name", __name, __signature) end
	        if not __s then return false, __e end
	        ------------
	        return true, os.getenv(name)
	    end),
	
	    -- Very basic implementation
	    execute = plume.obj.luaMacro("execute", function (args)
	        ------------
	        -- CHECKS --
	        ------------
	        local __name      = "execute"
	        local __signature = "string command"
	        local __s, __e, command
	        __s, __e, command = plume.stdUnpackPositional(args, 1, 1, __name, __signature)
	        if __s then __s, __e = plume.stdUnpackNamed(args, nil, __name, __signature) end
	        if __s then __s, __e = plume.stdCheckType(command, "string", "command", __name, __signature) end
	        if not __s then return false, __e end
	        ------------
	    	local success, result = pcall(function()
	    	    local h = io.popen(command)
	    		if not h then
	    			return nil
	    		end
	    		local r = h:read("*a")
	    		h:close()
	    		return r
	    	end)
	        return success, result
	    end)
	}
	
	local lfs = require"lfs"
	
	local function mkdirs(path, isFile)
		local fullPath = ""
		path = path:gsub('\\', '/')
		for frag in path:gmatch('[^/]+') do
			if fullPath ~= "" or path:sub(1, 1) == "/" then
				fullPath = fullPath .. "/"
			end
			fullPath = fullPath .. frag
			if isFile and path == fullPath then
				break
			end
	
			local attr = lfs.attributes(fullPath)
			if not attr then
				local success, result = lfs.mkdir(fullPath)
				if not success then
					return false, result
				end
			end
		end
		return true
	end
	
	local function makePath(path)
		local obj = plume.obj.quickTable{
			path = path or lfs.currentdir (),
			type = "Path",
			isFile = plume.obj.luaMacro ("isFile", function(args)
				local path = args.table.self.table.path
				local attr = lfs.attributes(path)
	
				if not attr then
					return true, false
				end
	
				return true, attr.mode == "file"
			end),
			isDirectory = plume.obj.luaMacro ("isDirectory", function(args)
				local path = args.table.self.table.path
				local attr = lfs.attributes(path)
	
				if not attr then
					return true, false
				end
	
				return true, attr.mode == "directory"
			end),
			exists = plume.obj.luaMacro ("exists", function(args)
				local path = args.table.self.table.path
				local attr = lfs.attributes(path)
				return true, attr ~= nil
			end),
			make = plume.obj.luaMacro ("make", function(args)
				local path = args.table.self.table.path
				local attr = lfs.attributes(path)
	
				if attr then
					return false, string.format("'%s' already exists, cannot create it.", path)
				end
	
				return mkdirs(path)
			end),
			remove = plume.obj.luaMacro ("remove", function(args)
				local path = args.table.self.table.path
				local attr = lfs.attributes(path)
	
				if not attr then
					return false, string.format("'%s' don't exists, cannot remove it.", path)
				end
	
				if attr.mode == "file" then
					return os.remove(path)
				else
					return lfs.rmdir(path)
				end
	
			end),
			move = plume.obj.luaMacro ("move", function(args)
				local path = args.table.self.table.path
				local newpath = args.table[1]
				local attr = lfs.attributes(path)
	
				if not attr then
					return false, string.format("'%s' don't exists, cannot move it.", path)
				end
	
				args.table.self.table.path = newpath
				return os.rename(path, newpath)
			end),
			copy = plume.obj.luaMacro ("copy", function(args)
				local path = args.table.self.table.path
				local newpath = args.table[1]
	
				local src = io.open(path)
				if not src then
					return false, string.format("Cannot read '%s'", src)
				end
				local dest = io.open(newpath, "w")
				if not dest then
					return false, string.format("Cannot write '%s'", dest)
				end
	
				dest:write(src:read("*a"))
				src:close()
				dest:close()
	
				return makePath(newpath)
			end),
	
			getParent = plume.obj.luaMacro ("getParent", function(args)
				local path = args.table.self.table.path
	
				if path:match('[/\\]') then
					return makePath(path:gsub('[/\\][^/\\]*$', ''))
				else
					return false, "Cannot return parent of root"
				end
			end),
			getName = plume.obj.luaMacro ("getName", function(args)
				local path = args.table.self.table.path
				return true, path:match('[^/\\]*$')
			end),
			read = plume.obj.luaMacro ("read", function(args)
				local path = args.table.self.table.path
				return plume.stdio.read(path)
			end),
			write = plume.obj.luaMacro ("write", function(args)
				local path = args.table.self.table.path
				local success, result = mkdirs(path, true)
				if not success then
					return false, result
				end
	
				local append = args.table.append
				return plume.stdio.write(path, table.concat(args.table), append)
			end),
			touch = plume.obj.luaMacro ("touch", function(args)
				local path = args.table.self.table.path
				local success, result = mkdirs(path, true)
				if not success then
					return false, result
				end
	
				local file = io.open(path, "w")
				if not file then
					return false, string.format("Cannot touch '%s'", path)
				end
				file:close()
				return true
			end),
			getChildren = plume.obj.luaMacro ("getChildren", function(args)
				local path = args.table.self.table.path
				local result = plume.obj.table(0, 0)
	
				for child in lfs.dir(path) do
					if child ~= "." and child ~= ".." then
						local _, childPath = makePath(path.."/"..child)
						table.insert(result.table, childPath)
						table.insert(result.keys, #result.table)
					end
				end
				return true, result
			end),
			walk = plume.obj.luaMacro ("walk", function(args)
				local path = args.table.self.table.path
				local result = plume.obj.table(0, 0)
	
				local toExplore = {path}
				local pos = 1
				while pos <= #toExplore do
					local path = toExplore[pos]
					pos = pos + 1
	
					for child in lfs.dir(path) do
						if child ~= "." and child ~= ".." then
							local childPath = path.."/"..child
							local _, childPathObj = makePath(childPath)
							table.insert(result.table, childPathObj)
							table.insert(result.keys, #result.table)
	
							table.insert(toExplore, childPath)
						end
					end
				end
				return true, result
			end)
		}
	
		local function div(x1, x2)
			local path1, path2
	
			if type(x1) == "string" then
				path1 = x1
			else
				path1 = x1.table.path
			end
	
			if type(x2) == "string" then
				path2 = x2
			else
				path2 = x2.table.path
			end
	
			return makePath(path1 .. "/" .. path2)
		end
	
		obj.meta = plume.obj.quickTable{
			tostring = plume.obj.luaMacro ("tostring", function(args)
				local path = args.table.self.table.path
				return true, path
			end),
	
			div = plume.obj.luaMacro ("div", function(args)
				return div(args.table[1], args.table[2])
			end)
		}
		
		return true, obj
	end
	
	table.insert(plume.std.os.keys, "Path")
	plume.std.os.table.Path = plume.obj.luaMacro("Path", function (args)
	    ------------
	    -- CHECKS --
	    ------------
	    local __name      = "Path"
	    local __signature = "[string path]"
	    local __s, __e, path
	    __s, __e, path = plume.stdUnpackPositional(args, 0, 1, __name, __signature)
	    if __s then __s, __e = plume.stdUnpackNamed(args, nil, __name, __signature) end
	    if __s and path then __s, __e = plume.stdCheckType(path, "string", "path", __name, __signature) end
	    if not __s then return false, __e end
	    ------------
	    return makePath(path)
	end)
	
	plume.std.Random = plume.obj.luaMacro("Random", function (args)
		------------
		-- CHECKS --
		------------
		local __name      = "Random"
		local __signature = "[number seed]"
		local __s, __e, seed
		__s, __e, seed = plume.stdUnpackPositional(args, 0, 1, __name, __signature)
		if __s then __s, __e = plume.stdUnpackNamed(args, nil, __name, __signature) end
		if __s and seed then __s, __e = plume.stdCheckType(seed, "number", "seed", __name, __signature) end
		if not __s then return false, __e end
		------------
	    
	
	    function _deriveSeed(seed, index)
			seed = ((seed + index * 1234567) * 1103515245 + 12345) % 2147483647
			if seed==0 then
				return 1
			else
				return seed
			end
		end
		local state = _deriveSeed(args.table[1] or os.time(), 1)
	
	    function _random()
	    	state = ((state * 48271) % 2147483647)
			return (state / 2147483647)
	    end
	    function _random_range(a, b)
			return math.floor(_random() * (b-a+1) + a)
	    end
	
	    local function shuffle(t)
			for k=1, #t.table do
				local i = _random_range(1, #t.table)
				local j = _random_range(1, #t.table)
	
				t.table[i], t.table[j] = t.table[j], t.table[i]
			end
		end
	   	
	    local random = plume.obj.quickTable{
		    seed = plume.obj.luaMacro ("seed", function(args)
		    	state = _deriveSeed(args.table[1] or os.time(), 1)
		    	return true
			end),
		    choice = plume.obj.luaMacro ("choice", function(args)
		    	local t = args.table[1]
		    	return true, t.table[_random_range(1, #t.table)]
			end),
			pchoice = plume.obj.luaMacro ("pchoice", function(args)
				local t = args.table[1]
				local tw = 0
				for _, k in ipairs(t.keys) do
					local v = t.table[k]
					if type(v) == "number" then
						tw = tw + v
					end
				end
				local r = _random() * tw
				tw = 0
				for _, k in ipairs(t.keys) do
					local v = t.table[k]
					if type(v) == "number" then
						tw = tw + v
						if tw>=r then
							return true, k
						end
					end
				end
			end),
			shuffle = plume.obj.luaMacro ("shuffle", function(args)
				shuffle(args.table[1])
		    	return true
			end),
			sample = plume.obj.luaMacro ("sample", function(args)
				local t = args.table[1]
				local count = args.table[2]
				if count > #t.table then
					return false, string.format("Cannot give a '%i'-size sample of a table with '%i' element%s.",
						count, #t.table, "s" and #t.table>1 or "")
				end
				t = plume.stdUtils.copy(t)
				shuffle(t)
	
				for i=#t.table, count+1, -1 do
					for j, key in ipairs(t.keys) do
						if key==i then
		    				t.keys[j] = nil
		    				break
		    			end
					end
					t.table[i] = nil
				end
		    	return true, t
			end)
		}
		random.meta = plume.obj.quickTable{
			call = plume.obj.luaMacro ("call", function(args)
				if #args.table == 0 then
		        	return true, _random()
		        elseif #args.table == 1 then
		        	return true, _random_range(0, args.table[1])
		        elseif #args.table == 2 then
		        	return true, _random_range(args.table[1], args.table[2])
		        end
			end)
		}
	    
	    return true, random
	end)
end

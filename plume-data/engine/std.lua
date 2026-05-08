--[[
This file is part of Plume🪶

Copyright © Erwan Barbedor
Licensed under the MIT License — see LICENSE for details.
]]

return function(plume)
	
	
	plume.std.os = plume.obj.quickTable {
	    getEnv = plume.obj.luaMacro("getEnv", function (args)
	        ------------
	        -- CHECKS --
	        ------------
	        local __name      = "getEnv"
	        local __signature = "string name"
	        local __s, __e, name
	        __s, __e, name = plume.stdUnpackPositional(args, 1, 1, __name, __signature)
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
end

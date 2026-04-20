--[[
This file is part of Plume🪶

Copyright © Erwan Barbedor
Licensed under the MIT License — see LICENSE for details.
]]

return function (plume)
	local lfs = require"lfs"


	local function makePath(path)
		local obj = plume.obj.table(0, 0)

		obj.keys = {"path", "type", "isFile", "isDirectory", "exists", "getParent", "getName", "read", "write", "make", "remove", "touch"}
		obj.table.path = path or lfs.currentdir ()
		obj.table.type = "Path"

		obj.table.isFile = plume.obj.luaMacro ("isFile", function(args)
			local path = args.table.self.table.path
			local attr = lfs.attributes(path)

			if not attr then
				return true, false
			end

			return true, attr.mode == "file"
		end)
		obj.table.isDirectory = plume.obj.luaMacro ("isDirectory", function(args)
			local path = args.table.self.table.path
			local attr = lfs.attributes(path)

			if not attr then
				return true, false
			end

			return true, attr.mode == "directory"
		end)
		obj.table.exists = plume.obj.luaMacro ("exists", function(args)
			local path = args.table.self.table.path
			local attr = lfs.attributes(path)
			return true, attr ~= nil
		end)
		obj.table.make = plume.obj.luaMacro ("make", function(args)
			local path = args.table.self.table.path
			local attr = lfs.attributes(path)

			if attr then
				return false, string.format("'%s' already exists, cannot create it.", path)
			end

			return lfs.mkdir(path)
		end)
		obj.table.remove = plume.obj.luaMacro ("remove", function(args)
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

		end)
		obj.table.move = plume.obj.luaMacro ("move", function(args)
			local path = args.table.self.table.path
			local newpath = args.table[1]
			local attr = lfs.attributes(path)

			if not attr then
				return false, string.format("'%s' don't exists, cannot move it.", path)
			end

			args.table.self.table.path = newpath
			return os.rename(path, newpath)
		end)
		obj.table.copy = plume.obj.luaMacro ("copy", function(args)
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
		end)

		obj.table.getParent = plume.obj.luaMacro ("getParent", function(args)
			local path = args.table.self.table.path

			if path:match('[/\\]') then
				return makePath(path:gsub('[/\\][^/\\]*$', ''))
			else
				return false, "Cannot return parent of root"
			end
		end)
		obj.table.getName = plume.obj.luaMacro ("getName", function(args)
			local path = args.table.self.table.path
			return true, path:match('[^/\\]*$')
		end)

		obj.table.read = plume.obj.luaMacro ("read", function(args)
			local path = args.table.self.table.path
			local file = io.open(path)
			if not file then
				return false, string.format("Cannot open '%s'", path)
			end
			local content = file:read("*a")
			file:close()
			return true, content
		end)
		obj.table.write = plume.obj.luaMacro ("write", function(args)
			local path = args.table.self.table.path
			local file = io.open(path, "w")
			if not file then
				return false, string.format("Cannot write '%s'", path)
			end
			file:write(table.concat(args.table))
			file:close()
			return true
		end)
		obj.table.touch = plume.obj.luaMacro ("touch", function(args)
			local path = args.table.self.table.path
			local file = io.open(path, "w")
			if not file then
				return false, string.format("Cannot touch '%s'", path)
			end
			file:close()
			return true
		end)

		obj.meta = plume.obj.table(0, 0)
		obj.meta.keys = {"tostring", div}
		obj.meta.table.tostring = plume.obj.luaMacro ("tostring", function(args)
			local path = args.table.self.table.path
			return true, path
		end)

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
		obj.meta.table.div = plume.obj.luaMacro ("div", function(args)
			return div(args.table[1], args.table[2])
		end)

		
		return true, obj
	end

	plume.std.os.table.Path = {
		checkArgs = {
			checkTypes = {"string"},
			signature = "[string path]",
			named={self=true},
			minArgs=0,
			maxArgs=1,
		},
		method = makePath
	}
end
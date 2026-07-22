--[[
This file is part of Plume🪶

Copyright © Erwan Barbedor
Licensed under the MIT License — see LICENSE for details.
]]

-- Copy string methods to Number and empty

plume.std.Empty = plume.obj.table(0, 0)
for _, name in ipairs(plume.std.String.keys) do
	local method = plume.std.String.table[name]
	plume.std.Number:setItem(name, plume.obj.luaMacro(name, function (args)
		if args.table.self then
			args.table.self = tostring(args.table.self)
		else
			args.table[1] = tostring(args.table[1])
		end
		return method.callable(args)
	end))

	plume.std.Empty:setItem(name, plume.obj.luaMacro(name, function (args)
		args.table.self = ""
		return method.callable(args)
	end))
end
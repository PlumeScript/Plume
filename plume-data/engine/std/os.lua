--[[
This file is part of Plume🪶

Copyright © Erwan Barbedor
Licensed under the MIT License — see LICENSE for details.
]]

return function (plume)
	plume.std.os = plume.obj.table (0, 0)

	plume.std.os.table.getEnv = {
        checkArgs = {
            checkTypes = {"string"},
            signature = "string name",
            named={self=true},
            args=1,
        },
        method = function (x)
            return true, os.getenv(x)
        end
    }

    -- Very basic implementation
    plume.std.os.table.execute = {
        checkArgs = {
            checkTypes = {"string"},
            signature = "string commande",
            named={self=true},
            args=1,
        },
        method = function (x)
        	local success, result = pcall(function()
			    local h = io.popen(x)
				if not h then
					return nil
				end
				local r = h:read("*a")
				h:close()
				return r
			end)
            return success, result
        end
    }
end
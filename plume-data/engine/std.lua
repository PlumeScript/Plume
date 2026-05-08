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
end

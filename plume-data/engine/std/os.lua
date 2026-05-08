plume.std.os = plume.obj.quickTable ({
    getEnv = plume.obj.luaMacro("getEnv", function (args)
        --!signature string name
        return true, os.getenv(name)
    end),

    -- Very basic implementation
    execute = plume.obj.luaMacro("execute", function (args)
        --!signature string command
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
})
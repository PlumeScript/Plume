--[[
This file is part of Plume🪶

Copyright © Erwan Barbedor
Licensed under the MIT License — see LICENSE for details.
]]

return function(plume)
	plume.error = {}

	require 'plume-data/engine/error/messages/core' (plume)
	require 'plume-data/engine/error/navigation'    (plume)
	require 'plume-data/engine/error/source'        (plume)
	require 'plume-data/engine/error/callstack'     (plume)
	require 'plume-data/engine/error/format'        (plume) 
	require 'plume-data/engine/error/distance'      (plume)
	require 'plume-data/engine/error/utils'         (plume)

	function plume.error.makeRuntimeError(runtime, ip, message)
		local errorInfos = plume.error.getRuntimeErrorInfos(runtime, ip, message)
		plume.lastErrorInfos = errorInfos
		return plume.error.formatError(errorInfos)
	end

	function plume.error.makeCompilationError(node, message)
		local errorInfos
		if plume.lastErrorInfos then
			errorInfos = plume.lastErrorInfos
			errorInfos.errorCallstack = errorInfos.errorCallstack or {}
			table.insert(errorInfos.errorCallstack, {node=node})
		else
			errorInfos = {message=message, sourceNode=node, header="COMPILATION ERROR:"}
			plume.lastErrorInfos = errorInfos
		end
		
		return plume.error.formatError(errorInfos)
	end

	function plume.error.makeSyntaxError(node, message)
		local errorInfos = {message=message, sourceNode=node, header="SYNTAX ERROR:"}
		plume.lastErrorInfos = errorInfos
		return plume.error.formatError(errorInfos)
	end

	function plume.error.makeStrictWarningError (node, message)
		local errorInfos = {message=message, sourceNode=node, header="STRICT WARNING ERROR:"}
		plume.lastErrorInfos = errorInfos
		return plume.error.formatError(errorInfos)
	end

	function plume.error.showWarnings()
		print(plume.error.formatError({}))
	end

	local unexpectedHeading = "Unexpected internal error. Please report it at https://github.com/PlumeScript/Plume."

	function plume.error.vmCrashHandler(err)
		local msg = unexpectedHeading

		msg = msg .. "\n\nLua error message:\n\t".. err
		msg = msg .. "\n"..debug.traceback("", 2)

		local ip
		-- Search for local variable "ip"
		local level = 2
		local found
        while not found do
            local info = debug.getinfo(level, "nSl")
            if not info then break end
             local i = 1
            while true do
                local name, value = debug.getlocal(level, i)
                if not name then break end
				
				if name == "vm" then
					name = "ip"
					value = value.ip
				end

                if name == "ip" then
                    found = true
                    ip = value
                    break
                end
                i = i + 1
            end
            level = level + 1
        end
		return {msg=msg, ip=ip or 1}
	end
	function plume.safeRun(run, vm,  startip, fileId)
		local novmcrash, success, result, ip = xpcall(run, plume.error.vmCrashHandler, vm, startip, fileId)
		if not novmcrash then
			result = success.msg or (type(success) == "string" and unexpectedHeading.."\n"..success)
			ip = success.ip or 1
			success = false
		end
		
		return success, result, ip
	end
end
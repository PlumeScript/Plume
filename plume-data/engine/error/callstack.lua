--[[
This file is part of Plume🪶

Copyright © Erwan Barbedor
Licensed under the MIT License — see LICENSE for details.
]]

return function(plume)
	local function simplifyErrorCallstack(errorCallstack)
		local windowSize = 1
		local detectedCount = 1
		while detectedCount > 0 and windowSize < #errorCallstack/2 do
			detectedCount = 0
			for i=1, #errorCallstack-windowSize do
				for j=i+windowSize, #errorCallstack, windowSize do
					local detection = true
					for k=0, windowSize do
						if not errorCallstack[i+k] or not errorCallstack[j+k] or errorCallstack[i+k].node ~= errorCallstack[j+k].node then
							detection = false
							break
						end
					end
					if not detection then
						break
					end
					detectedCount = detectedCount + i/windowSize
				end

				if detectedCount > 3 then
					local newErrorCallstack = {}
					for j=1, i-1 do
						table.insert(newErrorCallstack, errorCallstack[j])
					end
					if windowSize>1 then
						table.insert(newErrorCallstack, {repeatedBlockBegin=detectedCount})
					end

					
					for j=i, i+windowSize-1 do
						table.insert(newErrorCallstack, errorCallstack[j])
					end


					if windowSize>1 then
						table.insert(newErrorCallstack, {repeatedBlockEnd=true})
					else
						table.insert(newErrorCallstack, {repeated=detectedCount})
					end

					for j=i+(detectedCount+1)*windowSize+1, #errorCallstack do
						table.insert(newErrorCallstack, errorCallstack[j])
					end
					errorCallstack = newErrorCallstack
					break
				end
			end

			if detectedCount == 0 then
				windowSize = windowSize + 1
				detectedCount = 1
			end
		end
		return errorCallstack
	end

	local function getValidator(node, infos)
		local validator = plume.ast.get(node, "VALIDATOR")
		if validator then
			return true, validator
		end
		
		for _, info in ipairs(infos.errorCallstack) do
			if info.node then
				validator = plume.ast.get(info.node, "VALIDATOR")
				if validator then
					return false, validator
				end
			end
		end
	end

	local function handleValidator(node, infos)
		local direct, validator = getValidator(node, infos)
		if validator then
			infos.message = string.format("Validator '%s' failed:\n%s", validator.content, infos.message)
			if direct then -- remove redondant macro definition line
				table.remove(infos.errorCallstack, 1)
			end
		end
	end

	function plume.error.getRuntimeErrorInfos(runtime, ip, message)
		local infos

		local node = plume.error.getNode(runtime, ip)

		if node then
			local nodeParent = plume.error.findNodeParentMacro(node)

			if plume.lastErrorInfos then
				infos = plume.lastErrorInfos
				infos.errorCallstack = infos.errorCallstack or {}
				table.insert(infos.errorCallstack, {node=node, parentMacro=nodeParent})
			else 
				infos = {
					header="RUNTIME ERROR:",
					message=message,
					errorCallstack={},
				}
				infos.sourceNode       = node
				infos.sourceNodeParent = nodeParent
			end
		else
			infos = {
				header="RUNTIME ERROR:",
				message=message,
				errorCallstack={},
			}
		end
		
		if runtime.callstack then
			for i=#runtime.callstack, 1, -1 do
				local source = runtime.callstack[i]
				local node
				if source.macro.type == "macro" or source.macro.type == "luaMacro" and i>1 then
					node = plume.error.getNode(runtime, source.ip)
				end
				if node then
					local parentMacro = runtime.callstack[i-1]
					table.insert(infos.errorCallstack, {node=node, parentMacro=plume.error.findNodeParentMacro(node)})
				end
			end
		end

		infos.errorCallstack = simplifyErrorCallstack(infos.errorCallstack)

		if node then
			handleValidator(node, infos)
		end

		return infos
	end
end
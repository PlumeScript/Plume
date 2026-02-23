--[[This file is part of Plume

Plume🪶 is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, version 3 of the License.

Plume🪶 is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with Plume🪶.
If not, see <https://www.gnu.org/licenses/>.
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

	function plume.error.getRuntimeErrorInfos(runtime, ip, message)
		local infos

		local node = plume.error.getNode(runtime, ip)
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

		return infos
	end
end
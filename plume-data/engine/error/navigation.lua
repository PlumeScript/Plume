--[[
This file is part of Plume🪶

Copyright © Erwan Barbedor
Licensed under the MIT License — see LICENSE for details.
]]
return function(plume)
	function plume.error.getNode(runtime, ip)
		local node
		for i=ip, 1, -1 do
			node = runtime.mapping[i]
			if node and node.bpos then
				return node
			end
		end
		for i=ip+1, #runtime.bytecode do
			node = runtime.mapping[i]
			if node and node.bpos then
				return node
			end
		end
	end

	function plume.error.getMacroSignature(macro)
		if macro.node then
			local paramList = plume.ast.get(macro.node, "PARAMLIST")
			if paramList then
				local signature = paramList.code:sub(paramList.bpos, paramList.epos)
				if macro.name and macro.name ~= "???" then
					return "$"..macro.name .. signature
				else
					return string.format("$<macro>%s", signature)
				end
			end
		end
	end

	function plume.error.findNodeParentMacro (node)
		if node.name == "MACRO" then
			return node
		elseif node.parent then
			return plume.error.findNodeParentMacro(node.parent)
		end
	end

	function plume.error.addContext(nodeA, nodeB)
		nodeA.errorContext = nodeA.errorContext or {}
		table.insert(nodeA.errorContext, nodeB)
	end
end
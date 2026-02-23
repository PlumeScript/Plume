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
	function plume.error.getNode(runtime, ip)
		local node
		for i=ip, 1, -1 do
			node = runtime.mapping[i]
			if node and node.bpos then
				break
			end
		end
		return node
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
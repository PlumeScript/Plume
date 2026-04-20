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

return function (plume, context, nodeHandlerTable)
	nodeHandlerTable.FILE = context.file(function(node)
		local lets = context.countLocals(node)
		context.enterScope(lets, true)
		context.accBlock()(node, "macro_end")
		context.leaveScope()
	end)

	nodeHandlerTable.RUN = function(node)
		context.accBlock(function(node)
			context.childrenHandler(node)
		end)(node)
		context.registerOP(node, plume.ops.STORE_VOID)
	end

	nodeHandlerTable.DO = function(node)
		local body = plume.ast.get(node, "BODY")
		context.scope(function()
			context.accBlock()(body)
		end)(body)
	end

	nodeHandlerTable.WITH = function(node)
		if node.parent and node.parent.type == "TEXT" and node.type == "TABLE" then
			plume.error.withTableMuseBeAlone(node)
		end

		local body   = plume.ast.get(node, "BODY")
		local params = plume.ast.get(node, "PARAMLIST")

		for _, child in ipairs(params.children) do
			local name = plume.ast.get(child, "IDENTIFIER").content
			local value = plume.ast.get(child, "VALUE")
			
			context.registerOP(node, plume.ops.LOAD_CONSTANT, 0, context.registerConstant(name))
			context.accBlock()(value)
			context.registerOP(node, plume.ops.PUSH_CONTEXT)
		end

		context.accBlock()(body)
		
		for _, child in ipairs(params.children) do
			context.registerOP(node, plume.ops.POP_CONTEXT)
		end
	end
end
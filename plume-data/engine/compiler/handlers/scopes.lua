--[[
This file is part of Plume🪶

Copyright © Erwan Barbedor
Licensed under the MIT License — see LICENSE for details.
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

		if context.checkIfCanConcat() then
			context.registerOP(node, plume.ops.CHECK_IS_TEXT)
		end
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

		if context.checkIfCanConcat() then
			context.registerOP(node, plume.ops.CHECK_IS_TEXT)
		end
	end
end
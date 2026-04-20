--[[
This file is part of Plume🪶

Copyright © Erwan Barbedor
Licensed under the MIT License — see LICENSE for details.
]]

return function (plume, context, nodeHandlerTable)
	--- For a given node, call the appropriate handler to generate bytecode
	--- @param node node The node to process
	--- @return nil (Bytecode is directly added to chunk.instructions)
	function context.nodeHandler(node)
		context.checkForWarnings(node)
		local handler = nodeHandlerTable[node.name]
		if not handler then
			error("NYI tokenhandler " .. node.name) -- Guard against typo errors in parser
		end
		handler(node)
	end

	--- Handle all node children.
	--- Usefull to process structure body.
	--- Don't fail if node hasn't children.
	--- @param node node
	--- @return nil
	function context.childrenHandler(node)
		for _, child in ipairs(node.children or {}) do
			context.nodeHandler(child)
		end
	end

	nodeHandlerTable.NULL = function(node)
	end

	nodeHandlerTable.LINESTART = function(node)
	end
end
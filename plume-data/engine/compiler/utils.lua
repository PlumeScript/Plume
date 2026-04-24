--[[
This file is part of Plume🪶

Copyright © Erwan Barbedor
Licensed under the MIT License — see LICENSE for details.
]]

return function (plume, context)
	--- @param key string
	--- @return any last element of context[key]
	function context.getLast(key)
		return context[key][#context[key]]
	end

	local uid = 0
	--- Return each time a unique number
	--- Used to name labels
	---@return string
	function context.getUID()
		uid = uid+1
		return context.runtime.contextCount .. ":" .. uid
	end

	--- Register an opcode in the current chunk
	--- @param node node The source node to link the op with
	--- @param op number opcode constant, should be plume.op.SOMETHING
	--- @param arg1 number|nil First argument to give to the opcode. Default to 0.
	--- @param arg2 number|nil Second argument to give to the opcode. Default to 0.
	--- @param label string
	function context.registerOP(node, op, arg1, arg2, label)
		assert(op) -- Guard against opcode typo
		local current = context.runtime.instructions
		local instr   = {op, arg1 or 0, arg2 or 0, mapsto=node}
		if label then
			if not context.runtime.insert[label] then
				context.runtime.insert[label] = {}
			end
			table.insert(context.runtime.insert[label], instr)
		else
			table.insert(current, instr)
		end
	end

	--- Return the last scope of context.scopes
    --- @return table
    function context.getCurrentScope()  
        return context.scopes[#context.scopes]  
    end

    --- Utils to set/check if the current block is a TEXT one
    function context.toggleConcatOn()
    	table.insert(context.concats, true)
    end
    function context.toggleConcatOff()
    	table.insert(context.concats, false)
    end
    function context.toggleConcatPop()
    	table.remove(context.concats)
    end
    function context.checkIfCanConcat()
    	return context.getLast"concats"
    end

    --- Calculating number of declared local variables
    --- @param node node
    --- @return number
    function context.countLocals(node)
    	local lets      = plume.ast.getAll(node, "LET") 
    	local hashItems = plume.ast.getAll(node, "HASH_ITEM")

    	local count = #plume.ast.getAll(node, "MACRO")
    	for _, let in ipairs(lets) do
    		count = count + #plume.ast.get(let, "VARLIST").children
    	end
    	for _, hashItem in ipairs(hashItems) do
    		if plume.ast.get(hashItem, "REF") then
	    		count = count + 1
	    	end
    	end
    	return count
    end

    function context.checkArgsOrder(node)
    	local firstNamed, firstFlag, firstVariadic
    	for _, child in ipairs(node.children) do
    		if child.name == "LIST_ITEM" then
    			if firstFlag then
    				plume.error.cannotAddPositionalAfterFlag(child, true)
    			elseif firstNamed then
    				plume.error.cannotAddPositionalAfterNamed(child, true)
    			elseif firstVariadic then
    				plume.error.cannotAddPositionalAfterVariadic(child, true)
    			end
    		elseif child.name == "HASH_ITEM" then
    			if child.isFlag then
    				firstFlag = true
    				if firstVariadic then
    					plume.error.cannotAddFlagAfterVariadic(child, true)
    				end
    			else
    				firstNamed = true
    				if firstFlag then
    					plume.error.cannotAddNamedAfterFlag(child, true)
    				elseif firstVariadic then
    					plume.error.cannotAddNamedAfterVariadic(child, true)
    				end
    			end
    		elseif child.name == "EXPAND" then
    			firstVariadic = true
    		end
    	end
    end

    --- Collects comments that appear before the given node within its parent's children list.
	--- Iterates through all sibling nodes preceding the target node and gathers COMMENT tokens, ignoring those separated by a significant newline (anything other than LINESTART).
	--- @param node node to get adjacent comments
	--- @return string Concatenated comment strings separated by newlines (`\n`).
	function context.collectComments(node)
    	local parent = node.parent
    	if not parent then
    		return ""
    	end

    	local result = {}
    	local currentpos = 1
    	while currentpos<#parent.children and parent.children[currentpos] ~= node do
    		local child = parent.children[currentpos]
    		if child.name == "COMMENT" then
    			table.insert(result, child.content)
    		elseif child.name ~= "LINESTART" or child.content:match('\n.-\n') then
    			result = {}
    		end
    		currentpos = currentpos + 1
    	end

    	return table.concat(result, "\n")
    end
end
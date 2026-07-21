--[[
This file is part of Plume🪶

Copyright © Erwan Barbedor
Licensed under the MIT License — see LICENSE for details.
]]

return function (plume, context)
	--- @param key string
	--- @return any last element of context[key]
	function context.getLast(key, index)
		index = index or 0
		for i=#context.stacks, 1, -1 do
			if context.stacks[i].key == key then
				if index > 0 then
					index = index - 1
				else
					return context.stacks[i].value
				end
			end
		end
	end

	function context.getFirst(key, index)
		index = index or 0
		for i=1, #context.stacks, 1 do
			if context.stacks[i].key == key then
				if index > 0 then
					index = index - 1
				else
					return context.stacks[i].value
				end
			end
		end
	end

	function context.getCurrentFile()
		for i=#context.stacks, 1, -1 do
			if context.stacks[i].key == "macros" and context.stacks[i].value.isFile then
				return context.stacks[i].value
			end
		end
	end

	--- @param key string
	--- @param value any
	function context.append(key, value)
		table.insert(context.stacks, {key=key, value=value})
	end

	--- @param key string
	function context.remove(key)
		local lastIndex
		for i=#context.stacks, 1, -1 do
			if context.stacks[i].key == key then
				lastIndex = i
				break
			end
		end
		if not lastIndex then
			error(string.format('[Internal Error] Cannot found "%s" on compiler stack', key))
		end
		if lastIndex < #context.stacks then
			error(string.format('[Internal Error] Incoherent compiler stack, "%s" instead of "%s".', context.stacks[#context.stacks].key, key))
		end
		return table.remove(context.stacks, lastIndex)
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
		context.append("concats", true)
	end
	function context.toggleConcatOff()
		context.append("concats", false)
	end
	function context.toggleConcatPop()
		context.remove("concats")
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
		local withs     = plume.ast.getAll(node, "WITH")
		
		local count = #plume.ast.getAll(node, "MACRO")
		for _, let in ipairs(lets) do
			count = count + #plume.ast.get(let, "VARLIST").children
		end
		for _, with in ipairs(withs) do
			if with ~= node then
				local body = plume.ast.get(with, "BODY")
				count = count + context.countLocals(body)
			end
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
	--- Iterates through all sibling nodes preceding the target node and gathers COMMENT tokens,
	---- ignoring those separated by a significant newline (anything other than LINESTART).
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

		if #result == 0 then
			if parent.name == "DO" or parent.name == "BODY" or parent.name == "LET" then
				return context.collectComments(parent)
			end
		end

		return table.concat(result, "\n")
	end

	--- Collect file comments: any comment between file start and the first non-comment line.
	--- Warning: if the first non-comment line is LET, comment will be ignored.
	--- @param node node to get adjacent comments
	--- @return string Concatenated comment strings separated by newlines (`\n`).
	function context.collectFileComments(node)
		local result = {}
		local currentpos = 1
		for _, child in ipairs(node.children) do
			if child.name == "COMMENT" then
				table.insert(result, child.content)
			elseif child.name == "LET" then
				return ""
			else
				break
			end
		end
		return table.concat(result, "\n")
	end

	function context.safeClose(node, obj, leave)
		if not obj then
			return
		end
		for _, op in ipairs(obj.blockToClose or {}) do
			context.registerOP(node, op)
		end
		for _ = 1, obj.contextToClose or 0 do
			context.registerOP(node, plume.ops.POP_CONTEXT)
		end
		for _ = 1, obj.scopeToClose or 0 do
			context.registerOP(node, plume.ops.LEAVE_SCOPE)
		end
		if leave then
			context.registerOP(node, plume.ops.LEAVE_SCOPE)
		end
	end
end
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

return function (plume, context)
	--- @param key string
	--- @return any last element of context[key]
	function context.getLast(key)
		return context[key][#context[key]]
	end

	local uid = 0
	--- Return each time a unique number
	--- Used to name labels
	---@return number
	function context.getUID()
		uid = uid+1
		return uid
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
    	local lets = plume.ast.getAll(node, "LET") 
    	local count = #plume.ast.getAll(node, "MACRO")
    	for _, let in ipairs(lets) do
    		count = count + #plume.ast.get(let, "VARLIST").children
    	end
    	return count
    end
end
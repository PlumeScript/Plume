--[[
This file is part of Plume🪶

Copyright © Erwan Barbedor
Licensed under the MIT License — see LICENSE for details.
]]

return function(vm)
	--- @opcode
	--- Pop a table of context-variable bindings from the stack.
	--- For each key-value pair, pushes the variable's current value onto a cache stack
	--- and updates the variable to the new value.
	--! inline
	function vm:PUSH_CONTEXT(arg1, arg2)
	    local values = self:_STACK_POP(self.mainStack)

	    local cache = {}
		self:_STACK_PUSH(self.contextStackCache, cache)
	    for _, var in ipairs(values.keys) do
	        local value = values.table[var]

	        if type(var) ~= "table" or var.type ~= "context" then
	            self:_ERROR(self.plume.error.wrongContextType(var))
	        else
	            var:push(value)
	            table.insert(cache, var)
	        end
	    end
	end

	--- @opcode
	--- Restore all context variables to their previous values
	--- by popping the cache stack filled by `PUSH_CONTEXT`.
	--! inline
	function vm:POP_CONTEXT(arg1, arg2)
	    local cache = self:_STACK_POP(self.contextStackCache)
	    for _, var in ipairs(cache) do
	        var:pop()
	    end
	end
end

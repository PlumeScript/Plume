--[[
This file is part of Plume🪶

Copyright © Erwan Barbedor
Licensed under the MIT License — see LICENSE for details.
]]

return function(vm)
	--- @opcode
	--- Stack 1 from the constants table
	--- @param arg2 Constant offset
	--! inline
	function vm:LOAD_CONSTANT(arg1, arg2)
	    --- Stack 1 from constant
	    --- arg1: -
	    --- arg2: constant offset
	    local value = self.constants[arg2]

	    --! to-remove-begin
	    if value == nil then
	        self:_ERROR("[VM] Try to load a nil value.")
	    end
	    --! to-remove-end

		self:_STACK_PUSH(self.mainStack, value)
	end

	--- @opcode
	--- Stack 1 variable value
	--- @param arg1 Scope offset
	--- @param arg2 Variable offset
	--! inline
	function vm:LOAD_LOCAL(arg1, arg2)
		self:_STACK_PUSH(
		    self.mainStack,
			self:_STACK_GET_FRAMED(self.variableStack, arg2 - 1, -arg1)
	    )
	end

	--- @opcode
	--- Unstack 1, key
	--- Stack 1, key value in target accumulator
	--- @param arg1 Scope offset
	--! inline
	function vm:LOAD_REF(arg1, arg2)
	    local key = self:_STACK_POP(self.mainStack)
	    local pos = self:_GET_REF_POS(key, arg1)

	    if pos then
			self:_STACK_PUSH(self.mainStack, self:_STACK_GET(self.mainStack, pos))
	    else
			self:_STACK_PUSH(self.mainStack, self.plume.obj.empty)
	    end
	end

	--- @opcode
	--- Stack 1, `true`
	--! inline
	function vm:LOAD_TRUE(arg1, arg2)
		self:_STACK_PUSH(self.mainStack, true)
	end

	--- @opcode
	--- Stack 1, `false`
	--! inline
	function vm:LOAD_FALSE(arg1, arg2)
		self:_STACK_PUSH(self.mainStack, false)
	end

	--- @opcode
	--- Stack 1, `empty`
	--! inline
	function vm:LOAD_EMPTY(arg1, arg2)
		self:_STACK_PUSH(self.mainStack, self.plume.obj.empty)
	end
end

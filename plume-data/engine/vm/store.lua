--[[
This file is part of Plume🪶

Copyright © Erwan Barbedor
Licensed under the MIT License — see LICENSE for details.
]]

return function(vm)
	--- @opcode
	--- Set a local value
	--- Unstack 1, the value to set
	--- @param arg1 frame offset
	--- @param arg2 variable offset
	--! inline
	function vm:STORE_LOCAL(arg1, arg2)
		self:_STACK_SET_FRAMED(
		    self.variableStack,
			arg2-1,
			-arg1,
			self:_STACK_POP(self.mainStack)
	    )
	end

	--- @opcode
	--- Unstack 1, do nothing with it.
	--- Used to remove a value at stack top.
	--! inline
	function vm:STORE_VOID(arg1, arg2)
		self:_STACK_POP(self.mainStack)
	end

	--- @opcode
	--- Unstack 2, value, key
	--- Stack 1, key value in target accumulator
	--- @param arg1 Scope offset
	--! inline
	function vm:STORE_REF(arg1, arg2)
	    local key   = self:_STACK_POP(self.mainStack)
	    local value = self:_STACK_POP(self.mainStack)

		self:_STACK_SET(self.mainStack, self:_GET_REF_POS(key, arg1), value)
	end
end

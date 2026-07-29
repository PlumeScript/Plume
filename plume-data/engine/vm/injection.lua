--[[
This file is part of Plume🪶

Copyright © Erwan Barbedor
Licensed under the MIT License — see LICENSE for details.
]]

return function(vm)
	--- Get the last instruction from the injectionStack
	--- @return number, number, number
	--! inline
	function vm:_INJECTION_POP()
		self:_STACK_POP(self.injectionStack) -- deepth
		local arg2 = self:_STACK_POP(self.injectionStack)
		local arg1 = self:_STACK_POP(self.injectionStack)
		local op   = self:_STACK_POP(self.injectionStack)
		return op, arg1, arg2
	end

	--- Add an instruction at the injectionStack end
	--- @param op number
	--- @param arg1 number
	--- @param arg2 number
	--- @return nil
	--! inline
	function vm:_INJECTION_PUSH(op, arg1, arg2)
		self:_STACK_PUSH(self.injectionStack, op)
		self:_STACK_PUSH(self.injectionStack, arg1)
		self:_STACK_PUSH(self.injectionStack, arg2)
		self:_STACK_PUSH(self.injectionStack, self:_STACK_POS(self.macroStack))
	end

	--- Check if an injection is waiting AND in the macro that called it
	--! inline
	function vm:_CAN_INJECT()
		return self.injectionStack.pointer > 0 and self:_STACK_GET(self.injectionStack) == self:_STACK_POS(self.macroStack)
	end
end

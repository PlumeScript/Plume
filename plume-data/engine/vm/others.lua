--[[
This file is part of Plume🪶

Copyright © Erwan Barbedor
Licensed under the MIT License — see LICENSE for details.
]]

return function(vm)
	--- @opcode
	--- Switch two top stack values
	--! inline
	function vm:SWITCH(arg1, arg2)
	    local x = self:_STACK_POP(self.mainStack)
	    local y = self:_STACK_POP(self.mainStack)
		self:_STACK_PUSH(self.mainStack, x)
		self:_STACK_PUSH(self.mainStack, y)

	end

	--- @opcode
	--- Stack 1 more top stack value
	--! inline
	function vm:DUPLICATE(arg1, arg2)
		self:_STACK_PUSH(self.mainStack, self:_STACK_GET(self.mainStack))
	end
end

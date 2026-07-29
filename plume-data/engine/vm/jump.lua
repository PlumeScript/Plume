--[[
This file is part of Plume🪶

Copyright © Erwan Barbedor
Licensed under the MIT License — see LICENSE for details.
]]

return function(vm)
	--- @opcode
	--- Jump to a given instruction
	--- @param arg2 jump offset
	--! inline
	function vm:JUMP(arg1, arg2)
	    if self.jump > 0 and self.err then
	        -- dont erase error jump
	    else
	        self.jump = arg2
	    end
	end

	--! inline
	function vm:_RESET_JUMP()
	    self.jump = 0-- 0 instead of nil to preserve type
	end

	--- @opcode
	--- Pop 1, and jump to a given instruction if falsy (false or empty)
	--- @param arg2 jump offset
	--! inline
	function vm:JUMP_IF_NOT(arg1, arg2)
	    local test = self:_STACK_POP(self.mainStack)
	    if not self:_CHECK_BOOL(test) then
	        self:JUMP(0, arg2)
	    end
	end

	--- @opcode
	--- Unstack 1, and jump to a given instruction if true
	--- @param arg2 jump offset
	--! inline
	function vm:JUMP_IF(arg1, arg2)
	    local test = self:_STACK_POP(self.mainStack)
	    if self:_CHECK_BOOL(test) then
	        self:JUMP(0, arg2)
	    end
	end

	--- @opcode
	--- Jump to a given instruction if stack top is true
	--- @param arg2 jump offset
	--! inline
	function vm:JUMP_IF_PEEK(arg1, arg2)
	    local test = self:_STACK_GET(self.mainStack)
	    if self:_CHECK_BOOL(test) then
	        self:JUMP(0, arg2)
	    end
	end

	--- @opcode
	--- Jump to a given instruction if stack top is falsy (false or empty), without popping
	--- @param arg2 jump offset
	--! inline
	function vm:JUMP_IF_NOT_PEEK(arg1, arg2)
	    local test = self:_STACK_GET(self.mainStack)
	    if not self:_CHECK_BOOL(test) then
	        self:JUMP(0, arg2)
	    end
	end

	--- @opcode
	--- Unstack 1, and jump to a given instruction if empty
	--- @param arg2 jump offset
	--! inline
	function vm:JUMP_IF_EMPTY(arg1, arg2)
	    local test = self:_STACK_POP(self.mainStack)
	    if test == self.plume.obj.empty then
	        self:JUMP(0, arg2)
	    end
	end

	--- @opcode
	--- Unstack 1, and jump to a given instruction if any different from empty
	--- @param arg2 jump offset
	--! inline
	function vm:JUMP_IF_NOT_EMPTY(arg1, arg2)
	    local test = self:_STACK_POP(self.mainStack)
	    if test ~= self.plume.obj.empty then
	        self:JUMP(0, arg2)
	    end
	end

	--! inline
	function vm:_JUMP_END()
		self:JUMP(0, #self.bytecode)
	end
end

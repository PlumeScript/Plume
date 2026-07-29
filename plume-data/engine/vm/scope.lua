--[[
This file is part of Plume🪶

Copyright © Erwan Barbedor
Licensed under the MIT License — see LICENSE for details.
]]

return function(vm)
	--- @opcode
	--- Create a new frame and set all it's variable to empty
	--- @param arg1 number Number of local variables already stacked
	--- @param arg2 number Number of local variables
	--! inline
	function vm:ENTER_SCOPE(arg1, arg2)
		self:_STACK_PUSH(
		    self.variableStack.frames,
			self:_STACK_POS(self.variableStack) + 1 - arg1
	    )

	    for i = 1, arg2-arg1 do
			self:_STACK_PUSH(self.variableStack, self.plume.obj.empty)
	    end
	end

	--- @opcode
	--- Close a frame
	--! inline
	function vm:LEAVE_SCOPE(arg1, arg2)
		self:_STACK_POP_FRAME(self.variableStack)
	end

	--- @opcode
	--- Return from the current file execution.
	--- Closes the file scope, pops the file stack and the callstack.
	--- If the file stack is empty, signals program termination.
	--- Otherwise jumps back to the caller and caches the result if applicable.
	--! inline
	function vm:RETURN_FILE(arg1, arg2)
		self:LEAVE_SCOPE()
		self:_STACK_POP(self.fileStack)
		self:_POP_CALLSTACK()

		if self:_STACK_POS(self.fileStack) == 0 then
			self:_JUMP_END()
		else
		    --! to-remove-begin
		    if self.jump > 0 then
		        self:_ERROR("[VM] RETURN_FILE overwriting a pending jump.")
		    end
		    --! to-remove-end
			self:JUMP(0, self:_STACK_POP(self.macroStack)) -- return in the previous position
		end

	    -- Cache result
	    local file = self:_GET_CURRENT_FILE()
	    if file and file.cacheId then
	        self.runtime.cache.results[file.cacheId] = self:_STACK_GET(self.mainStack)
	    end
	end

	--- @opcode
	--- Distribute file parameters (saved by `STD_IMPORT`) into local variable slots.
	--- Runs once at the start of file execution, then clears the parameter list.
	--! inline
	function vm:FILE_INIT_PARAMS(arg1, arg2)
	    local params = self.fileParams
	    if params then
	        for _, paramInfos in ipairs(params) do
				self:_STACK_SET_FRAMED(self.variableStack, paramInfos.offset-1, 0, paramInfos.value)
	        end
	        self.fileParams = nil
	    end
	end

	--- @opcode
	--- Pop a message from the stack and raise a runtime error.
	--! inline
	function vm:RAISE(arg1, arg2)
	    local msg = self:_STACK_POP(self.mainStack)
	    self:_ERROR(msg)
	end
end

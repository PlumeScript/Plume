--[[
This file is part of Plume🪶

Copyright © Erwan Barbedor
Licensed under the MIT License — see LICENSE for details.
]]

return function(vm)
	--- Add a macro to the callstack, with current ip
	---@param vm VM The virtual machine instance.
	---@param macro table The called macro
	--! inline
	function vm:_PUSH_CALLSTACK(macro, safe)
		local callinfos = {runtime=self.runtime, macro=macro, ip=self.ip, safe=safe}
		if self.ip == self.plume.sops.CONCAT_CALL or self.ip == self.plume.sops.CONCAT_CALL_SAFE then --recursive call
			callinfos.base = #self.runtime.callstack
			callinfos.ip = self:_STACK_GET(self.recursiveStack)
		end

		table.insert(self.runtime.callstack, callinfos)
		if #self.runtime.callstack>1000 then
			self:_ERROR(self.plume.error.stackOverflow())
		end
	end

	--- Remove a macro from callstack
	---@param vm VM The virtual machine instance.
	--! inline
	function vm:_POP_CALLSTACK()
	    local call = table.remove(self.runtime.callstack)

	    if call and call.safe then
	        local result = self:_STACK_POP(self.mainStack)
	        local safeResult = self.plume.obj.table(0, 2)
	        safeResult:setItem("success", true)
	        safeResult:setItem("result", result)
			self:_STACK_PUSH(self.mainStack, safeResult)
	    end

	    if call and call.base then
	        if call.base == #self.runtime.callstack then
	            self:_JUMP_END()
	            return true
	        end
	    end
	end

	--- @opcode
	--- @param arg1 Flag, 1 for a validator flag
	--- @param arg2 Flag, 1 for the safe mode
	--- Take the stack top to call, with all elements of the current frame as parameters.
	--- Stack the call result (or empty if nil)
	--- Handle macros and luaMacro
	--! inline
	function vm:CONCAT_CALL(arg1, arg2)
	    local tocall = self:_STACK_POP(self.mainStack)
	    local t = self:_GET_TYPE(tocall)
	    local self_param


	    -- Table can be called with, if exists, the meta-field call
	    if t == "table" then
	        local mvalidate = tocall:getMetaItem("validate")
	        local mcall     = tocall:getMetaItem("call")
	        if arg1==1 and mvalidate then
	            self_param = tocall
	            tocall = mvalidate
	            t = tocall.type
	        elseif mcall then
	            self_param = tocall
	            tocall = mcall
	            t = tocall.type
	        end
	    end

	    -- Macro
	    if t == "macro"  then
	        if self_param then
				self:_PUSH_SELF(self_param)
	        end

			self:_CALL_MACRO(tocall, arg1==1, arg2==1)
			self:_STACK_PUSH(self.closureStack, {})

	    elseif t == "closure" then
	        if self_param then
				self:_PUSH_SELF(self_param)
	        end

			self:_CALL_MACRO(tocall.macro, arg1==1, arg2==1)
			self:_STACK_PUSH(self.closureStack, tocall.upvalues)

	    -- Std functions defined in lua or user lua functions
	    elseif t == "luaMacro" then
	        self:CONCAT_TABLE()
			self:_PUSH_CALLSTACK(tocall, arg2==1)

	        local args        = self:_STACK_POP(self.mainStack)
	        local currentFile = self:_STACK_GET(self.fileStack)

			self:_SAVE_SCALAR()
	        local success, result = tocall.callable (args, self, currentFile)
			self:_UPDATE_SCALAR()

	        if success then
	            if result == nil then
	                result = self.plume.obj.empty
	            end
				self:_STACK_PUSH(self.mainStack, result)
	            self:_POP_CALLSTACK()
	        else
	            self:_ERROR(result)
	        end
	    -- Contextal variables
	    elseif t == "context" then
	        self:CONCAT_TABLE()
			self:_STACK_POP(self.mainStack) -- Remove args
			self:_STACK_PUSH(self.mainStack, tocall:get())

	    -- @table ... end just return the accumulated table
	    elseif tocall == self.plume.std.Table then
	        self:CONCAT_TABLE()

	    -- FORCE_FRAGMENT do exactly the same thing as tostring
	    elseif tocall == self.plume.std.String then

	        local value = self:_STACK_POP(self.mainStack)
			self:_STACK_POP_FRAME(self.mainStack)
			self:_STACK_PUSH(self.mainStack, value)
	        -- Should check for to many arguments, instead of ignoring them
	        self:FORCE_FRAGMENT()
			self:CHECK_IS_TEXT()

	    elseif tocall == self.plume.std.attempt then
	        local macro = self:_STACK_GET_FRAMED(self.mainStack, 0)
	        local tmacro = self:_GET_TYPE(macro)

	        if tmacro ~= "macro" and tmacro ~= "closure" and tmacro ~= "luaMacro" then
	            self:_ERROR(string.format("`attempt` first argument must be a macro, not a '%s'.", tmacro))
	        end

	        -- Macro should be at the end
	        local frameBegin = self:_STACK_GET(self.mainStack.frames)
	        local frameEnd   = self:_STACK_POS(self.mainStack)
	        for i = frameBegin, frameEnd-1 do
	            self.mainStack[i] = self.mainStack[i+1]
	        end
	        self.mainStack[frameEnd] = macro

			self:_PUSH_CALLSTACK(tocall, arg2==1)
			self:_CONCAT_CALL_SAFE_REC()
			self:_POP_CALLSTACK()
	    elseif tocall == self.plume.std.import then
	        local args = self:CONCAT_TABLE()
			self:_PUSH_CALLSTACK(tocall, arg2==1)
			self:STD_IMPORT()
	    else
	        self:_ERROR(self.plume.error.cannotCallValue(t))
	    end
	end

	---@param vm VM The virtual machine instance.
	---@param chunk table The function chunk to call.
	---@param bool isValidator
	--! inline
	function vm:_CALL_MACRO(chunk, isValidator, safe)
	    if isValidator and chunk.positionalParamCount ~= 1 then
	        self:_ERROR(self.plume.error.wrongValidatorArgsCount(chunk, chunk.positionalParamCount))
	    else
			self:ENTER_SCOPE(0, chunk.localsCount) -- Create a new scope

	        -- Distribute arguments to locals and get the overflow table
	        local variadicTable, tomanyPositionnalCounter, capturedCount, unknownNamed = self:_CONCAT_TABLE(
	            chunk.positionalParamCount,
	            chunk.namedParamOffset,
	            chunk.variadicOffset
	        )

	        if tomanyPositionnalCounter>0 then
	            self:_ERROR(self.plume.error.wrongArgsCount(
	                chunk,
	                chunk.positionalParamCount+tomanyPositionnalCounter,
	                chunk.positionalParamCount
	            ))
	        elseif capturedCount < chunk.positionalParamCount then
	            self:_ERROR(self.plume.error.wrongArgsCount(
	                chunk,
	                capturedCount,
	                chunk.positionalParamCount
	            ))
	        elseif unknownNamed then
	            self:_ERROR(self.plume.error.unknownParameter(unknownNamed, chunk))
	        else
	            -- If the chunk expects a variadic argument, assign the table to the specific register
	            if chunk.variadicOffset then
					self:_STACK_SET_FRAMED(self.variableStack, chunk.variadicOffset - 1, 0, variadicTable)
	            end
				self:_PUSH_CALLSTACK(chunk, safe)
				self:_STACK_POP_FRAME(self.mainStack)        -- Clean stack from arguments
				self:_STACK_PUSH(self.macroStack, self.ip + 1) -- Set the return pointer
				self:JUMP(0, chunk.offset)             -- Jump to macro body
	        end
	    end
	end

	--- @opcode
	--- Return from the current macro call.
	--- Closes the macro scope, pops the closure stack, pops the callstack,
	--- and jumps back to the saved return address.
	--! inline
	function vm:RETURN(arg1, arg2)
		self:LEAVE_SCOPE(0, 0) -- close macro scope
		self:_STACK_POP(self.closureStack)
		local exit = self:_POP_CALLSTACK()
		local ret  = self:_STACK_POP(self.macroStack)
		if not exit then
			self:JUMP(0, ret) -- return in the previous position
		end
	end
end

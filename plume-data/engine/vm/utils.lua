--[[
This file is part of Plume🪶

Copyright © Erwan Barbedor
Licensed under the MIT License — see LICENSE for details.
]]

return function(vm)
	--- @param x any
	--- @return string Type of x
	--! inline
	function vm:_GET_TYPE(x)
	    return type(x) == "table" and (x == self.plume.obj.empty and "empty" or x.type) or (type(x) == "cdata" and x.type) or type(x)
	end

	--! inline
	function vm:_IS_CALLABLE(x)
		local _type = vm:_GET_TYPE(x)
		return _type == "macro" or _type == "closure" or _type == "luaMacro" or _type == "stdMacro" or (_type == "table" and x.meta and x.meta.table.call) or x == self.plume.std.Table or x == self.plume.std.String or x == self.plume.std.attempt
	end

	--- Throw an error
	--- @param msg string
	--- @return nil
	--! inline
	function vm:_ERROR(msg, _customerrip)
		self.err = msg
	    self:_HANDLE_ERROR(_customerrip) --! to-remove
	    --! to-add customerrip = _customerrip
	    --! to-add _temp_goto_error()
	end

	--! inline
	function vm:_HANDLE_ERROR(customerrip)
	    local safeCallIndex
	    for i = #self.runtime.callstack, 1, -1 do
	        local call = self.runtime.callstack[i]
	        if call.safe then
	            safeCallIndex = i
	        end
	    end

	    -- Logic duplication with _POP_CALLSTACK - see #1084
	    if safeCallIndex then
	    	local msg = self.err
	    	self.err = nil
	        local returnRun = false
	        for i=#self.runtime.callstack, safeCallIndex, -1 do
	            local call = table.remove(self.runtime.callstack)
	            if call and call.base then
	                if call.base == #self.runtime.callstack then
	                    returnRun = true
	                    self:_JUMP_END() --! to-remove
	                end
	            end
	            self:LEAVE_SCOPE(0, 0)
	            self:_STACK_POP(self.closureStack)
	            self:_STACK_POP(self.macroStack)
	        end
	        local safeResult = self.plume.obj.table(0, 2)
	        safeResult:setItem("success", false)
	        safeResult:setItem("result", msg)
	        if not returnRun then
	            self:RETURN()
	            --! to-add _temp_goto_dispatch()
	        end
	        self:_STACK_PUSH(self.mainStack, safeResult)

	    else
	        self.errip = customerrip or self.ip
	        self:_JUMP_END() --! to-remove
	    end
	end

	--- @param x any
	--- @return any|false Return false if x is empty, else x it self.
	--! inline
	function vm:_CHECK_BOOL(x)
	    if x == self.plume.obj.empty then
	        return false
	    end
	    return x
	end

	--- Find offset corresponding to a key in the current building table
	--- @param key string
	--- @param offset number
	--! inline
	function vm:_GET_REF_POS(key, offset)
	    offset = offset-1 -- frames start at 0

	    local frameBottom
	    if offset == 0 then
	        frameBottom = 1
	    else
	        frameBottom = self:_STACK_GET(self.mainStack.frames, offset)
	    end

	    local frameTop
	    if offset == self:_STACK_POS(self.mainStack.frames)-1 or offset==0 then
	        frameTop = self:_STACK_POS(self.mainStack)+1
	    else
	        frameTop = self:_STACK_GET(self.mainStack.frames, offset+1)
	    end

	    --! to-remove-begin
	    if not frameTop or frameTop <= 0 then
	        self:_ERROR("[VM] Wrong frameTop, cannot find current ref.")
	        return
	    end
	    if not frameBottom or frameBottom <= 0 then
	        self:_ERROR("[VM] Wrong frameBottom, cannot find current ref.")
	        return
	    end
	    --! to-remove-end

	    for i = frameTop-1, frameBottom, -1 do
	        if self.tagStack[i] == "key" then
	            if self:_STACK_GET(self.mainStack, i) == key then
	                return i-1 -- Value is just before the key
	            end
	        end
	    end
	end

	--! inline
	function vm:_GET_CURRENT_FILE()
	    local lastfile
	    local files = self.runtime.files
	    local ip    = self.ip
	    for _, file in ipairs(files) do
	        if file.offset then
	            if file.offset <= ip then
	                if not lastfile or file.offset > lastfile.offset then
	                    lastfile = file
	                end
	            end
	        end
	    end

	    return lastfile
	end

	--! inline
	function vm:_FINAL_CHECKS()
	    if self.mainStack.pointer > 1 then
	        return false, "[Internal Error] To many elements on stack."
	    elseif self.mainStack.pointer == 0 then
	        return false, "[Internal Error] Stack empty."
	    end

	    return true
	end

	--! inline
	function vm:_SAVE_SCALAR()
	    --! save-scalar
	end

	--! inline
	function vm:_UPDATE_SCALAR()
	    --! update-scalar
	end
end

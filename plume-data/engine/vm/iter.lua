--[[
This file is part of Plume🪶

Copyright © Erwan Barbedor
Licensed under the MIT License — see LICENSE for details.
]]

return function(vm)
	--- @opcode
	--- Pop 1 iterable object and push its iterator triple (flag, state, value).
	--- If object has a meta field `next`, it's already an iterator, and will be returned as-is.
	--- If object has a meta field `iter`, call it.
	--- Else, push the default sequence iterator.
	--- Raise an error if the object isn't a table.
	--! inline
	function vm:GET_ITER(arg1, arg2)
	    local obj = self:_STACK_POP(self.mainStack)
	    local tobj = self:_GET_TYPE(obj)

	    local iter, value, flag, macrocall
	    local start = 0
	    if tobj == "table" then
	        if obj:getMetaItem("next") then
	            iter = obj
	        else
	            iter = obj:getMetaItem("iter")
	        end


	        if iter then
	            if iter.type == "luaMacro" then
	                value = iter.callable({obj})
	            elseif iter.type == "table" then
	                value = iter
	            elseif iter.type == "macro" then
	                macrocall = true
	            end
	            flag = self.flag.ITER_CUSTOM
	        else
	            value = obj.table
	            flag = self.flag.ITER_TABLE
	        end

	    elseif tobj == "stdIterator" then
	        value = obj
	        flag = obj.flag
	        start = obj.start or start
	    else
	        self:_ERROR(self.plume.error.cannotIterateValue(tobj))
	    end

	    --! to-remove-begin
	    if not self.err then -- only needed in dev mode, to prevent STACK_PUSH to crash
	    --! to-remove-end
			self:_STACK_PUSH(self.mainStack, flag)
			self:_STACK_PUSH(self.mainStack, start) -- state
	        if macrocall then -- call will add the value
	            self:BEGIN_ACC(0, 0)
				self:_PUSH_SELF(obj)
				self:_STACK_PUSH(self.mainStack, iter)
	            self:CONCAT_CALL(0, 0)
	        else
				self:_STACK_PUSH(self.mainStack, value)
	        end

	    --! to-remove-begin
	    end
	    --! to-remove-end

	    -- GET_ITER is followed by 3 STORE_LOCAL
	end

	--- @opcode
	--- Advance the iterator stored in local variables (obj, state, flag).
	--- If the result is empty, jump to the loop end.
	--- Otherwise, push the next value onto the value stack.
	--- @param arg2 number Offset of the loop end
	--! inline
	function vm:FOR_ITER(arg1, arg2)
	    local obj   = self:_STACK_GET_FRAMED(self.variableStack, 0, 0)
	    local state = self:_STACK_GET_FRAMED(self.variableStack, 1, 0)
	    local flag  = self:_STACK_GET_FRAMED(self.variableStack, 2, 0)

	    local result, call
	    if flag == self.flag.ITER_TABLE then
	        state = state+1

	        if state > #obj then
	            result = self.plume.obj.empty
	        else
	            result = obj[state]
	        end
	    elseif flag == self.flag.ITER_SEQ then
	        state = state + obj.step
	        if obj.step > 0 and state > obj.stop or obj.step < 0 and state < obj.stop then
	            result = self.plume.obj.empty
	        else
	            result = state
	        end
	    elseif flag == self.flag.ITER_ENUMS then
	        state = state+1

	        if state > #obj.ref.table then
	            result = self.plume.obj.empty
	        else
	            -- Could be optimized
	            result = self.plume.obj.table(2, 0)
	            result:addItem(state)
	            result:addItem(obj.ref.table[state])
	        end
	    elseif flag == self.flag.ITER_ITEMS then
	        state = state+1

	        if obj.named then
	            while tonumber(obj.ref.keys[state]) do
	                state = state+1
	            end
	        end

	        if state > #obj.ref.keys then
	            result = self.plume.obj.empty
	        else
	            -- Could be optimized
	            result = self.plume.obj.table(2, 0)
	            result:addItem(obj.ref.keys[state])
	            result:addItem(obj.ref.table[result.table[1]])
	        end
	    elseif flag == self.flag.ITER_CUSTOM then
	        local iter = obj:getMetaItem("next")
	        if iter.type == "luaMacro" then
	            result = iter.callable()
	        else
	            call = true

	            self:BEGIN_ACC(0, 0)
				self:_PUSH_SELF(obj)
				self:_STACK_PUSH(self.mainStack, iter)
	            self:_CONCAT_CALL_REC()
				self:JUMP_FOR(0, arg2)

	        end
	    else
	        error(string.format("[VM] Unkonwn flag '%s'"), flag)
	    end

	    if not call then
	        -- Save state. Offset 1 for local var #2
			self:_STACK_SET_FRAMED(self.variableStack, 1, 0, state)

	        if result == self.plume.obj.empty then
	            self:JUMP(0, arg2)
	        else
				self:_STACK_PUSH(self.mainStack, result)
	        end
	    end
	end

	--- @opcode
	--- Check the result of a custom iterator's `next` meta-macro call.
	--- If the value is falsy (false or empty), pop it and jump to the loop end.
	--- Otherwise, leave the value on the stack for the loop body.
	--- @param arg2 jump offset
	--! inline
	function vm:JUMP_FOR(arg1, arg2)
	    local test = self:_STACK_GET(self.mainStack)
	    if not self:_CHECK_BOOL(test) then
	        self:_STACK_POP(self.mainStack)
	        self:JUMP(0, arg2)
	    end
	end
end

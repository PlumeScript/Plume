--[[
This file is part of Plume🪶

Copyright © Erwan Barbedor
Licensed under the MIT License — see LICENSE for details.
]]

return function(vm)
	--- @opcode
	--- Create a new table, waiting CONCAT_TABLE or CALL
	--- @param arg1 number Number of hash slot to allocate
	--! inline
	function vm:TABLE_NEW(arg1, arg2)
		self:_STACK_PUSH(self.mainStack, table.new(0, arg1))
	end

	--- @opcode
	--- Mark the last element of the stack as a key
	--! inline
	function vm:TAG_KEY(arg1, arg2)
		local pos = self:_STACK_POS(self.mainStack)
		self.tagStack[pos] = "key"
	end

	--- @opcode
	--- Mark the last element of the stack as a meta-key
	--! inline
	function vm:TAG_META_KEY(arg1, arg2)
	    local name = self:_STACK_GET(self.mainStack)
	    local value = self:_STACK_GET(self.mainStack, self:_STACK_POS(self.mainStack)-1)
	    local valid, err = self:_META_CHECK(name, value)
	    if not valid then
	        self:_ERROR(err)
	    end
		local pos = self:_STACK_POS(self.mainStack)
		self.tagStack[pos] = "metakey"
	end

	--- @opcode
	--- Add a key to the current accumulation table (bottom of the current frame)
	--- Unstack 2: a key, then a value
	--- @param arg2 number 1 if the key should be registered as metafield
	--! inline
	function vm:TABLE_SET_ACC(arg1, arg2)
	    local t = self:_STACK_GET_FRAMED(self.mainStack)

	    table.insert(t, self:_STACK_POP(self.mainStack)) -- key
	    table.insert(t, self:_STACK_POP(self.mainStack)) -- value
	    table.insert(t, arg2==1)                  -- is meta
	end

	--- @opcode
	--- Unstack 3, in order: table, key, value
	--- Set the table.key to value
	--! inline
	function vm:TABLE_SET_META(arg1, arg2)
	    local t     = self:_STACK_POP(self.mainStack)
	    local key   = self:_STACK_POP(self.mainStack)
	    local value = self:_STACK_POP(self.mainStack)
	    t:setMetaItem(key, value)
	end

	--- @opcode
	--- Index a table
	--- Unstack 2, in order: table, key
	--- Stack 1, `table[key]`
	--- @param arg1 number 1 if "safe mode" (return empty if key not exit), 0 else (raise error if key not exist)
	--! inline
	function vm:TABLE_INDEX(arg1, arg2)
	    local t   = self:_STACK_POP(self.mainStack)
	    local key = self:_STACK_POP(self.mainStack)
	    key = tonumber(key) or key

	    if key == self.plume.obj.empty then
	        if arg1 == 1 then
	            self:LOAD_EMPTY()
	        else
	            self:_ERROR(self.plume.error.cannotUseEmptyAsKey())
	        end
	    else
	        
	    	local tt = self:_GET_TYPE(t)
	        if tt == "fragment" then
	        	self:_STACK_PUSH(self.mainStack, t)
	        	self:FORCE_FRAGMENT()
	        	t  = self:_STACK_POP(self.mainStack)
	        	tt = self:_GET_TYPE(t)
	        end

	        
	        if not tonumber(key) then
	            if tt == "string" then
	                t = self.plume.std.String
	                tt = "table"
	            end
	            if tt == "empty" then
	                t = self.plume.std.Empty
	                tt = "table"
	            end
	            if tt == "number" then
	                t = self.plume.std.Number
	                tt = "table"
	            end
	        end



	        if tt ~= "table" then
	            if arg1 == 1 then
	                self:LOAD_EMPTY()
	            else
	                self:_ERROR(self.plume.error.cannotIndexValue(tt))
	            end
	        else
	            local value = t.table[key]
	            if value ~= nil then
					self:_STACK_PUSH(self.mainStack, value)
	            else
	                local mgetindex = t:getMetaItem("getindex")
	                if arg1 == 1 then
	                    self:LOAD_EMPTY()
	                elseif mgetindex then
	                    self:BEGIN_ACC(0, 0)
						self:_STACK_PUSH(self.mainStack, key)
						self:_PUSH_SELF(t)
						self:_STACK_PUSH(self.mainStack, mgetindex)
	                    self:_CONCAT_CALL_REC()
						self:TABLE_INDEX_CHECK_IS_NIL()
	                else
	                    self:_ERROR(self.plume.error.unregisteredKey(t, key))
	                end
	            end
	        end
	    end
	end

	--- @opcode
	--- Check the return value of a `getindex` meta-macro call.
	--- If the result is empty, raise an error (the key was not found).
	--! inline
	function vm:TABLE_INDEX_CHECK_IS_NIL()
	    local top = self:_STACK_GET(self.mainStack)
	    if top == self.plume.obj.empty then
	       self:_ERROR(self.plume.error.getindexReturnsEmpty())
	    end
	end

	--- @param self table
	--- Register a table as the value for the field self
	--- in the current accumulation table
	--! inline
	function vm:_PUSH_SELF(self_param)
		self:_STACK_PUSH(self.mainStack, self_param)
		self:_STACK_PUSH(self.mainStack, "self")
		self:TAG_KEY()
	end

	--- @opcode
	--- The stack may be [(frame begin)| call arguments | index | table]
	--- Insert self | table in the call arguments
	--! inline
	function vm:CALL_INDEX_REGISTER_SELF(arg1, arg2)
	    local t = self:_STACK_POP(self.mainStack)
	    local index = self:_STACK_POP(self.mainStack)


		self:_STACK_PUSH(self.mainStack, t)
		self:_STACK_PUSH(self.mainStack, "self")
		self:TAG_KEY()
		self:_STACK_PUSH(self.mainStack, index)
		self:_STACK_PUSH(self.mainStack, t)
	end

	--- @opcode
	--- Unstack 3, in order: table, key, value
	--- Set the table.key to value
	--! inline
	function vm:TABLE_SET(arg1, arg2)
	    local t, key, value

	    t     = self:_STACK_POP(self.mainStack)
	    key   = self:_STACK_POP(self.mainStack)
	    value = self:_STACK_POP(self.mainStack)

	    local mreadonly = t:getMetaItem("readonly")
	    local msetindex
	    key = tonumber(key) or key

	    if mreadonly then
	        self:_ERROR(self.plume.error.cannotSetIndexReadonlyTable())
	    elseif not t.table[key] then
	        msetindex = t:getMetaItem("setindex")
	        if msetindex then
	            -- value
	            self:BEGIN_ACC(0, 0)
				self:_STACK_PUSH(self.mainStack, key)
				self:_STACK_PUSH(self.mainStack, value)
				self:_PUSH_SELF(t)
				self:_STACK_PUSH(self.mainStack, msetindex)
	            self:_CONCAT_CALL_REC()

	            value = self:_STACK_POP(self.mainStack)
	        end
	    end

	    if not msetindex and not mreadonly then
	        t:setItem(key, value)
	    end
	end

	--- @opcode
	--- Unstack 1: a table
	--- Stack all list item
	--- Put all hash item on the stack
	--! inline
	function vm:TABLE_EXPAND(arg1, arg2)
	    local t  = self:_STACK_POP(self.mainStack)
	    local tt = self:_GET_TYPE(t)
	    if tt == "table" then
	        for _, item in ipairs(t.table) do
				self:_STACK_PUSH(self.mainStack, item)
	        end

	        for _, key in ipairs(t.keys) do
	            if not tonumber(key) then
					self:_STACK_PUSH(self.mainStack, t.table[key])
					self:_STACK_PUSH(self.mainStack, key)
	                self:TAG_KEY()
	            end
	        end
	    else
	        self:_ERROR(self.plume.error.cannotExpandValue(tt))
	    end
	end

	--- @opcode
	--- Set a custom field (from the constant pool) on the table at stack top.
	--- The table is not popped. Used internally by the engine for table metadata.
	--! inline
	function vm:TABLE_CUSTOM_FIELD(arg1, arg2)
	    local field = self.constants[arg2]
	    local value = self:_STACK_POP(self.mainStack)
	    local t     = self:_STACK_GET(self.mainStack)
	    t[field]    = value
	end
end

--[[
This file is part of Plume🪶

Copyright © Erwan Barbedor
Licensed under the MIT License — see LICENSE for details.
]]

return function(vm)
	--! inline
	function safeGetMetaItem(t, name)
		return t.getMetaItem and t:getMetaItem(name)
	end

	--- Try to convert any value into number.
	--- Via tonumber, or try to call the metafield tonumber.
	--- @param x any
	--- @return number|nil, string The converted value, or nil + an error message
	--! inline
	function vm:_CHECK_NUMBER_META(x)
	    local tx = self:_GET_TYPE(x)
	    if tx  == "string" then
	        if not tonumber(x) then
	            return x, self.plume.error.cannotConvertToString(x)
	        end
	        x = tonumber(x)
	    elseif tx  ~= "number" then
	        local mtonumber = safeGetMetaItem(x, "tonumber")
	        if tx  == "table" and mtonumber then
	            local meta = mtonumber
	            local params = {}
	            return self:_CALL(meta, params)
	        else
	            return x, self.plume.error.cannotDoArithmeticWith(tx)
	        end
	    end
	    return x
	end

	--- For a given operation name, try to find a meta macro to do the operation.
	--- If find one, call it.
	--- @param left any
	--- @param right any
	--- @param name string Operation name
	--- @return false|true, any(call result)
	--! inline
	function vm:_HANDLE_META_BIN(left, right, name)
	    local meta, param1, param2, paramself
	    local tleft  = self:_GET_TYPE(left)
	    local tright = self:_GET_TYPE(right)

	    local leftmetar  = tleft == "table" and safeGetMetaItem(left, name.."r")
	    local rightmetal = tright == "table" and safeGetMetaItem(right, name.."l")
	    local leftmeta   = tleft == "table" and safeGetMetaItem(left, name)
	    local rightmeta  = tright == "table"and safeGetMetaItem(right, name)

	    if leftmetar then
	        meta = leftmetar
	        param1 = right
	        paramself = left
	    elseif rightmetal then
	        meta = rightmetal
	        param1 = left
	        paramself = right
	    elseif leftmeta then
	        meta = leftmeta
	        param1 = left
	        param2 = right
	        paramself = left
	    elseif rightmeta then
	        meta = rightmeta
	        param1 = left
	        param2 = right
	        paramself = right
	    end

	    if meta then
	        self:BEGIN_ACC(0, 0)
			self:_STACK_PUSH(self.mainStack, param1)
	        if param2 then
	            self:_STACK_PUSH(self.mainStack, param2)
	        end

			self:_PUSH_SELF(paramself)
			self:_STACK_PUSH(self.mainStack, meta)
			self:_CONCAT_CALL_REC()
	    end

	    return meta
	end

	--- For a given operation name, try to find a meta macro to do the operation.
	--- If find one, call it.
	--- @param x any The value to process
	--- @param name string Operation name
	--- @return false|true, any(call result)
	--! inline
	function vm:_HANDLE_META_UN(x, name)
	    local meta, paramself
	    meta = self:_GET_TYPE(x) == "table" and safeGetMetaItem(x, name)

	    if meta then
	        self:BEGIN_ACC(0, 0)
			self:_PUSH_SELF(x)
			self:_STACK_PUSH(self.mainStack, meta)
			self:_CONCAT_CALL_REC()
	    end

	    return meta
	end

	--- Unstack 2 value, apply an boolean operation, stack the result.
	--- If an value is `empty`, act like it was false.
	--- @param op function Operation to apply
	--! inline
	function vm:_BIN_OP_BOOL(op)
	    local right = self:_STACK_POP(self.mainStack)
	    local left  = self:_STACK_POP(self.mainStack)

	    right = self:_CHECK_BOOL(right)
	    left  = self:_CHECK_BOOL(left)

		self:_STACK_PUSH(self.mainStack, op(self, left, right))
	end

	--- Unstack 1 value, apply an boolean operation, stack the result.
	--- If the value is `empty`, act like it was false.
	--- @param op function Operation to apply
	--! inline
	function vm:_UN_OP_BOOL(op)
	    local x = self:_STACK_POP(self.mainStack)
	    x = self:_CHECK_BOOL(x)
		self:_STACK_PUSH(self.mainStack, op(self, x))
	end

	--- `_BIN_OP_NUMBER` isn't an opcode, but tag as opcode for be integrated in the documentation.
	--- @opcode
	--- Unstack 2 value, apply an operation, stack the result.
	--- Try to convert values to number.
	--- If cannot, try to call meta macro based on operator name
	--- @param op function Operation to apply
	--- @param name string Name used to find meta macro and debug messages
	--! inline
	function vm:_BIN_OP_NUMBER(op, name)
		local right = self:_STACK_POP(self.mainStack)
		local left  = self:_STACK_POP(self.mainStack)

		local rightNumber = tonumber(right)
		local leftNumber = tonumber(left)

		-- Only number
		if rightNumber and leftNumber then
			local result = op(self, leftNumber, rightNumber)
			self:_STACK_PUSH(self.mainStack, result)
		else

			local rerr, lerr

			right, rerr = self:_CHECK_NUMBER_META(right)
			left, lerr  = self:_CHECK_NUMBER_META(left)

			-- table with metafield for this operator
			if lerr or rerr then
				local meta = self:_HANDLE_META_BIN(left, right, name)
				if not meta then
					if name == "add" then
						if type(right) == "string" then
							lerr = self.plume.error.cannotConvertToString(right, true)
						elseif type(left) == "string" then
							lerr = self.plume.error.cannotConvertToString(left, true)
						end
					end
					self:_ERROR(lerr or rerr)
				end
			-- table with tonumber metafield
			else
				local result = op(self, left, right)
				self:_STACK_PUSH(self.mainStack, result)
			end


		end
	end

	--- Unstack 1 value, apply an operation, stack the result.
	--- @param op function Operation to apply
	--- @param name string Name used to find meta macro and debug messages
	--! inline
	function vm:_UN_OP_NUMBER(op, name)
	    local x = self:_STACK_POP(self.mainStack)
	    local err, meta

	    x, err = self:_CHECK_NUMBER_META(x)

	    if err then
	        meta = self:_HANDLE_META_UN(x, name)
	        if not meta then
	             self:_ERROR(err)
	        end
	    else
			self:_STACK_PUSH(self.mainStack, op(self, x))
	    end
	end

	----------------
	--- Arithmetics
	----------------

	--! inline
	function vm:_ADD(x, y)
		return x+y
	end
	--! inline
	function vm:_MUL(x, y)
		return x*y
	end
	--! inline
	function vm:_SUB(x, y)
		return x-y
	end
	--! inline
	function vm:_DIV(x, y)
		return x/y
	end
	--! inline
	function vm:_MOD(x, y)
		return x%y
	end
	--! inline
	function vm:_POW(x, y)
		return x^y
	end
	--! inline
	function vm:_NEG(x)
		return -x
	end

	--- @opcode
	--- Add two stack top value and stack the result based on `_BIN_OP_NUMBER`.
	--! inline
	function vm:OP_ADD(arg1, arg2)
		self:_BIN_OP_NUMBER(vm._ADD,   "add")
	end
	--- @opcode
	--- Concatenate two stack top values and stack the result.
	--- Both operands are guaranteed to be text by CHECK_IS_TEXT.
	--! inline
	function vm:OP_CONCAT(arg1, arg2)
		local right = self:_STACK_POP(self.mainStack)
		local left  = self:_STACK_POP(self.mainStack)
		self:_STACK_PUSH(self.mainStack, left .. right)
	end
	--- @opcode
	--- Multiply two stack top value and stack the result based on `_BIN_OP_NUMBER`.
	--! inline
	function vm:OP_MUL(arg1, arg2)
		self:_BIN_OP_NUMBER(vm._MUL,   "mul")
	end
	--- @opcode
	--- Substract two stack top value and stack the result based on `_BIN_OP_NUMBER`.
	--! inline
	function vm:OP_SUB(arg1, arg2)
		self:_BIN_OP_NUMBER(vm._SUB,   "sub")
	end
	--- @opcode
	--- Divide two stack top value and stack the result based on `_BIN_OP_NUMBER`.
	--! inline
	function vm:OP_DIV(arg1, arg2)
		self:_BIN_OP_NUMBER(vm._DIV,   "div")
	end
	--- @opcode
	--- Take the modulo of stack top value and stack the result based on `_BIN_OP_NUMBER`.
	--! inline
	function vm:OP_MOD(arg1, arg2)
		self:_BIN_OP_NUMBER(vm._MOD,   "mod")
	end
	--- @opcode
	--- Take the power of two stack top value and stack the result based on `_BIN_OP_NUMBER`.
	--! inline
	function vm:OP_POW(arg1, arg2)
		self:_BIN_OP_NUMBER(vm._POW,   "pow")
	end
	--- @opcode
	--- Give opposite of a value
	--! inline
	function vm:OP_NEG(arg1, arg2)
		self:_UN_OP_NUMBER(vm._NEG,   "minus")
	end

	---------
	--- Bool
	---------

	--! inline
	function vm:_AND(x, y)
		return x and y
	end
	--! inline
	function vm:_OR(x, y)
		return x or y
	end
	--! inline
	function vm:_NOT(x)
		return not x
	end

	--- @opcode
	--- Do boolean `and` between two stack top values based on `_BIN_OP_BOOL`.
	--! inline
	function vm:OP_AND(arg1, arg2)
		self:_BIN_OP_BOOL(vm._AND)
	end
	--- @opcode
	--- Do boolean `or` between two stack top values based on `_BIN_OP_BOOL`.
	--! inline
	function vm:OP_OR(arg1, arg2)
		self:_BIN_OP_BOOL(vm._OR)
	end
	--- @opcode
	--- Do boolean `not` between stack top value based on `_BIN_OP_BOOL`.
	--! inline
	function vm:OP_NOT(arg1, arg2)
		self:_UN_OP_BOOL(vm._NOT)
	end

	---------------
	--- Comparison
	---------------

	--- Do comparison `<` between two stack top values based on `_BIN_OP_NUMBER`.
	--- @param x left value
	--- @param y right value
	--! inline
	function vm:_LT(x, y)
		return x < y
	end

	--- @opcode
	--- Do comparison `<` between two stack top values based on `_BIN_OP_NUMBER`.
	--! inline
	function vm:OP_LT(arg1, arg2)
		self:_BIN_OP_NUMBER(vm._LT, "lt")
	end

	--- @opcode
	--- Do comparison `==` between two values.
	--- If both value are string representations of number,
	--- return the comparison between theses two numbers.
	--! inline
	function vm:OP_EQ(arg1, arg2)
		local right = self:_STACK_POP(self.mainStack)
		local left  = self:_STACK_POP(self.mainStack)

		local meta  = self:_HANDLE_META_BIN(left, right, "eq")

		if not meta then
		    -- `(false)` instead of `false` preventing make-engine-opt optimization
		    local result = left == right or tonumber(left) and tonumber(left) == tonumber(right) or (false)
			self:_STACK_PUSH(self.mainStack, result)
		end


	end
end

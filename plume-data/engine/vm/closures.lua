--[[
This file is part of Plume🪶

Copyright © Erwan Barbedor
Licensed under the MIT License — see LICENSE for details.
]]

return function(vm)
	--! inline
	function vm:_UPVALUE_OFFSET(localoffset, scopeoffset)
		return self:_STACK_GET_OFFSET(self.variableStack.frames, -(scopeoffset or 0)) + localoffset - 1
	end

	--- @opcode
	--- Register a local variable slot as an open upvalue by its absolute offset.
	--- Future `CLOSURE` calls will bind the cell at this offset.
	--- @param arg2 local offset
	--! inline
	function vm:OPEN_UPVALUE(arg1, arg2)
		local offset  = self:_UPVALUE_OFFSET(arg2)
		self.upvalueMap[offset] = {
			reference = self.variableStack,
			offset    = offset
		}
	end

	--- @opcode
	--- Pop a key from the stack and register a pending reference upvalue for it.
	--- The reference is resolved to a table field when `CLOSE_REF_UPVALUE` runs.
	--! inline
	function vm:OPEN_REF_UPVALUE(arg1, arg2)
		local key = self:_STACK_POP(self.mainStack)

		local upvalue = {emptyRef=true}

		if self.upvalueMap[key] then
			table.insert(self.upvalueMap[key], upvalue)
		else
			self.upvalueMap[key] = {upvalue}
		end
	end

	--- @opcode
	--- Freeze an open upvalue by copying the variable's current value into a cell.
	--- The upvalue cell then references the cell instead of the live variable stack.
	--- @param arg2 local offset
	--! inline
	function vm:CLOSE_UPVALUE(arg1, arg2)
		local offset  = self:_UPVALUE_OFFSET(arg2)
		local upvalue = self.upvalueMap[offset]
		upvalue[1] = upvalue.reference[upvalue.offset]

		upvalue.reference = upvalue
		upvalue.offset    = 1

		self.upvalueMap[offset] = nil
	end

	--- @opcode
	--- Pop a key from the stack and resolve the matching reference upvalue.
	--- Binds it to the table field at that key (stack top is the newly created table).
	--! inline
	function vm:CLOSE_REF_UPVALUE(arg1, arg2)
		local key = self:_STACK_POP(self.mainStack)
		local t   = self:_STACK_GET(self.mainStack) -- stack top is the newly created table

		local map = self.upvalueMap[key]
	    --! to-remove-begin
	    if map == nil then
	        error(string.format("[VM] Not upvalue map for key '%s'.", key))
	        return
	    elseif #map==0 then
	    	error("[VM] Empty upvalueMap.")
	    	return
	    end
	    --! to-remove-end

		local upvalue = table.remove(map)

		upvalue.reference = t.table
		upvalue.offset    = key

		if #self.upvalueMap[key] == 0 then
			self.upvalueMap[key] = nil
		end
	end

	--- @opcode
	--- Push the value of an upvalue from the current closure's upvalue table.
	--- @param arg2 local offset
	--! inline
	function vm:LOAD_UPVALUE(arg1, arg2)
		local upvalue = self:_STACK_GET(self.closureStack)[arg2]
		self:_STACK_PUSH(self.mainStack, upvalue.reference[upvalue.offset])
	end

	--- @opcode
	--- Pop a value and store it into an upvalue cell in the current closure's upvalue table.
	--! inline
	function vm:STORE_UPVALUE(arg1, arg2)
		local upvalue = self:_STACK_GET(self.closureStack)[arg2]
		upvalue.reference[upvalue.offset] = self:_STACK_POP(self.mainStack)
	end

	--- @opcode
	--- Create a closure object from the macro reference on stack top.
	--- Binds all declared upvalues (by parent offset, ref key, or local offset)
	--- into a new upvalue table. Replaces the macro with the closure on the stack.
	--! inline
	function vm:CLOSURE(arg1, arg2)
		local macro = self:_STACK_GET(self.mainStack)
		if #macro.upvalues > 0 then
			local macroClosure = {
				type = "closure",
				macro = macro,
				upvalues = {}
			}
			self:_STACK_SET(self.mainStack, self:_STACK_POS(self.mainStack), macroClosure)
			for _, upvalueInfos in ipairs(macro.upvalues) do
				local upvalue
				if upvalueInfos.parentOffset then
					upvalue = self:_STACK_GET(self.closureStack)[upvalueInfos.parentOffset]
				elseif upvalueInfos.isRefUpvalue then
					upvalue = self.upvalueMap[upvalueInfos.key][#self.upvalueMap[upvalueInfos.key]]
					if upvalue.emptyRef then
						upvalue.emptyRef  = nil
						upvalue.reference = self.mainStack
						upvalue.offset    = self:_GET_REF_POS(upvalueInfos.key, upvalueInfos.blockPosition)
						if not upvalue.offset then
							-- The offset cannot be found.
							-- Assume this is because CLOSURE is called just before
							-- the target object is added to the table.
							-- So  target the next position
							upvalue.offset = vm:_GET_REF_FRAME_TOP(upvalueInfos.blockPosition)+1
						end
					end
				else
					local offset = self:_UPVALUE_OFFSET(upvalueInfos.localOffset, upvalueInfos.scopeOffset)
					upvalue = self.upvalueMap[offset]
				end
				macroClosure.upvalues[upvalueInfos.offset] = upvalue
			end
		end
	end
end

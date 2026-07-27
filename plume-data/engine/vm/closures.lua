--[[
This file is part of Plume🪶

Copyright © Erwan Barbedor
Licensed under the MIT License — see LICENSE for details.
]]

--! inline
function _UPVALUE_OFFSET(vm, localoffset, scopeoffset)
	return _STACK_GET_OFFSET(vm, vm.variableStack.frames, -(scopeoffset or 0)) + localoffset - 1
end

--- @opcode
--- Register a local variable slot as an open upvalue by its absolute offset.
--- Future `CLOSURE` calls will bind the cell at this offset.
--- @param arg2 local offset
--! inline
function OPEN_UPVALUE (vm, arg1, arg2)
	local offset  = _UPVALUE_OFFSET(vm, arg2)
	vm.upvalueMap[offset] = {
		reference = vm.variableStack,
		offset    = offset
	}
end

--- @opcode
--- Pop a key from the stack and register a pending reference upvalue for it.
--- The reference is resolved to a table field when `CLOSE_REF_UPVALUE` runs.
--! inline
function OPEN_REF_UPVALUE (vm, arg1, arg2)
	local key = _STACK_POP(vm, vm.mainStack)

	local upvalue = {emptyRef=true}

	if vm.upvalueMap[key] then
		table.insert(vm.upvalueMap[key], upvalue)
	else
		vm.upvalueMap[key] = {upvalue}
	end
end

--- @opcode
--- Freeze an open upvalue by copying the variable's current value into a cell.
--- The upvalue cell then references the cell instead of the live variable stack.
--- @param arg2 local offset
--! inline
function CLOSE_UPVALUE (vm, arg1, arg2)
	local offset  = _UPVALUE_OFFSET(vm, arg2)
	local upvalue = vm.upvalueMap[offset]
	upvalue[1] = upvalue.reference[upvalue.offset]

	upvalue.reference = upvalue
	upvalue.offset    = 1

	vm.upvalueMap[offset] = nil
end

--- @opcode
--- Pop a key from the stack and resolve the matching reference upvalue.
--- Binds it to the table field at that key (stack top is the newly created table).
--! inline
function CLOSE_REF_UPVALUE (vm, arg1, arg2)
	local key = _STACK_POP(vm, vm.mainStack)
	local t   = _STACK_GET(vm, vm.mainStack) -- stack top is the newly created table

	local map = vm.upvalueMap[key]
	--! to-remove-begin
    if map == nil then
        _ERROR (vm, string.format("[VM] Not upvalue map for key '%s'.", key))
        return
    elseif #map==0 then
    	_ERROR (vm, "[VM] Empty upvalueMap.")
    	return
    end
    --! to-remove-end

	local upvalue = table.remove(map)

	upvalue.reference = t.table
	upvalue.offset    = key

	if #vm.upvalueMap[key] == 0 then
		vm.upvalueMap[key] = nil
	end
end

--- @opcode
--- Push the value of an upvalue from the current closure's upvalue table.
--- @param arg2 local offset
--! inline
function LOAD_UPVALUE (vm, arg1, arg2)
	local upvalue = _STACK_GET(vm, vm.closureStack)[arg2]
	_STACK_PUSH(vm, vm.mainStack, upvalue.reference[upvalue.offset])
end

--- @opcode
--- Pop a value and store it into an upvalue cell in the current closure's upvalue table.
--! inline
function STORE_UPVALUE (vm, arg1, arg2)
	local upvalue = _STACK_GET(vm, vm.closureStack)[arg2]
	upvalue.reference[upvalue.offset] = _STACK_POP(vm, vm.mainStack)
end

--- @opcode
--- Create a closure object from the macro reference on stack top.
--- Binds all declared upvalues (by parent offset, ref key, or local offset)
--- into a new upvalue table. Replaces the macro with the closure on the stack.
--! inline
function CLOSURE (vm, arg1, arg2)
	local macro = _STACK_GET(vm, vm.mainStack)
	if #macro.upvalues > 0 then
		local macroClosure = {
			type = "closure",
			macro = macro,
			upvalues = {}
		}
		_STACK_SET(vm, vm.mainStack, _STACK_POS(vm, vm.mainStack), macroClosure)
		for _, upvalueInfos in ipairs(macro.upvalues) do
			local upvalue
			if upvalueInfos.parentOffset then
				upvalue = _STACK_GET(vm, vm.closureStack)[upvalueInfos.parentOffset]
			elseif upvalueInfos.isRefUpvalue then
				upvalue = vm.upvalueMap[upvalueInfos.key][#vm.upvalueMap[upvalueInfos.key]]
				if upvalue.emptyRef then
					upvalue.emptyRef  = nil
					upvalue.reference = vm.mainStack
					upvalue.offset    = _GET_REF_POS(vm, upvalueInfos.key, upvalueInfos.blockPosition)
				end
			else
				local offset = _UPVALUE_OFFSET(vm, upvalueInfos.localOffset, upvalueInfos.scopeOffset)
				upvalue = vm.upvalueMap[offset]	
			end
			macroClosure.upvalues[upvalueInfos.offset] = upvalue
		end
	end
end
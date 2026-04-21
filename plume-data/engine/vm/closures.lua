--[[
This file is part of Plume🪶

Copyright © Erwan Barbedor
Licensed under the MIT License — see LICENSE for details.
]]

--! inline
function _UPVALUE_OFFSET(vm, localoffset, scopeoffset)
	return _STACK_GET_OFFSET(vm.variableStack.frames, -(scopeoffset or 0)) + localoffset - 1
end

--- @opcode
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
--! inline
function OPEN_REF_UPVALUE (vm, arg1, arg2)
	local key = _STACK_POP(vm.mainStack)

	local upvalue = {emptyRef=true}

	if vm.upvalueMap[key] then
		table.insert(vm.upvalueMap[key], upvalue)
	else
		vm.upvalueMap[key] = {upvalue}
	end
end

--- @opcode
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
--! inline
function CLOSE_REF_UPVALUE (vm, arg1, arg2)
	local key = _STACK_POP(vm.mainStack)
	local t   = _STACK_GET(vm.mainStack) -- stack top is the newly created table
	local upvalue = table.remove(vm.upvalueMap[key])

	upvalue.reference = t.table
	upvalue.offset    = key

	if #vm.upvalueMap[key] == 0 then
		vm.upvalueMap[key] = nil
	end
end

--- @opcode
--- @param arg2 local offset
--! inline
function LOAD_UPVALUE (vm, arg1, arg2)
	local upvalue = _STACK_GET(vm.closureStack)[arg2]
	_STACK_PUSH(vm.mainStack, upvalue.reference[upvalue.offset])
end

--- @opcode
--! inline
function STORE_UPVALUE (vm, arg1, arg2)
	local upvalue = _STACK_GET(vm.closureStack)[arg2]
	upvalue.reference[upvalue.offset] = _STACK_POP(vm.mainStack)
end

--- @opcode
--! inline
function CLOSURE (vm, arg1, arg2)
	local macro = _STACK_GET(vm.mainStack)
	if #macro.upvalues > 0 then
		local macroClosure = {
			type = "closure",
			macro = macro,
			upvalues = {}
		}
		_STACK_SET(vm.mainStack, _STACK_POS(vm.mainStack), macroClosure)
		for _, upvalueInfos in ipairs(macro.upvalues) do
			local upvalue
			if upvalueInfos.parentOffset then
				upvalue = _STACK_GET(vm.closureStack)[upvalueInfos.parentOffset]
			elseif upvalueInfos.isRefUpvalue then
				upvalue = vm.upvalueMap[upvalueInfos.key][#vm.upvalueMap[upvalueInfos.key]]
				if upvalue.emptyRef then
					upvalue.emptyRef  = nil
					upvalue.reference = vm.mainStack
					upvalue.offset    = _GET_REF_POS(vm, upvalueInfos.key, upvalueInfos.scopeOffset)
				end
			else
				local offset = _UPVALUE_OFFSET(vm, upvalueInfos.localOffset, upvalueInfos.scopeOffset)
				upvalue = vm.upvalueMap[offset]	
			end
			macroClosure.upvalues[upvalueInfos.offset] = upvalue
		end
	end
end
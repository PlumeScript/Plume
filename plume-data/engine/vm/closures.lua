--[[This file is part of Plume

Plume🪶 is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, version 3 of the License.

Plume🪶 is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with Plume🪶.
If not, see <https://www.gnu.org/licenses/>.
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
function CLOSE_UPVALUE (vm, arg1, arg2)
	local offset  = _UPVALUE_OFFSET(vm, arg2)
	local upvalue = vm.upvalueMap[offset]
	upvalue[1] = upvalue.reference[upvalue.offset]

	upvalue.reference = upvalue
	upvalue.offset    = 1

	vm.upvalueMap[offset] = nil
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
			local offset = _UPVALUE_OFFSET(vm, upvalueInfos.localOffset, upvalueInfos.scopeOffset)
			local upvalue = vm.upvalueMap[offset]
			macroClosure.upvalues[upvalueInfos.offset] = upvalue
		end
	end
end
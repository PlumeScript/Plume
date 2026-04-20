--[[
This file is part of Plume🪶

Copyright © Erwan Barbedor
Licensed under the MIT License — see LICENSE for details.
]]

--- Get the last instruction from the injectionStack
--- @return number, number, number
--! inline
function _INJECTION_POP(vm)
	_STACK_POP(vm.injectionStack) -- deepth
	local arg2 = _STACK_POP(vm.injectionStack)
	local arg1 = _STACK_POP(vm.injectionStack)
	local op   = _STACK_POP(vm.injectionStack)
	return op, arg1, arg2
end

--- Add an instruction at the injectionStack end
--- @param op number
--- @param arg1 number
--- @param arg2 number
--- @return nil
--! inline
function _INJECTION_PUSH(vm, op, arg1, arg2)
	_STACK_PUSH(vm.injectionStack, op)
	_STACK_PUSH(vm.injectionStack, arg1)
	_STACK_PUSH(vm.injectionStack, arg2)
	_STACK_PUSH(vm.injectionStack, _STACK_POS(vm.macroStack))
end

--- Check if an injection is waiting AND in the macro that called it
--! inline
function _CAN_INJECT(vm)
	return vm.injectionStack.pointer > 0 and _STACK_GET(vm.injectionStack) == _STACK_POS(vm.macroStack)
end
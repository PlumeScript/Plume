--[[
This file is part of Plume🪶

Copyright © Erwan Barbedor
Licensed under the MIT License — see LICENSE for details.
]]

--- @opcode
--- Set a local value
--- Unstack 1, the value to set
--- @param arg1 frame offset
--- @param arg2 variable offset
--! inline
function STORE_LOCAL (vm, arg1, arg2)
    _STACK_SET_FRAMED(
        vm.variableStack,
        arg2-1,
        -arg1,
        _STACK_POP(vm.mainStack)
    )
end

--- @opcode
--- Unstack 1, do nothing with it.
--- Used to remove a value at stack top.
--! inline
function STORE_VOID (vm, arg1, arg2)
    _STACK_POP(vm.mainStack)
end

--- @opcode
--- Unstack 2, value, key
--- Stack 1, key value in target accumulator
--- @param arg1 Scope offset
--! inline
function STORE_REF (vm, arg1, arg2)
    local key   = _STACK_POP(vm.mainStack)
    local value = _STACK_POP(vm.mainStack)

    _STACK_SET(vm.mainStack, _GET_REF_POS(vm, key, arg1), value)
end
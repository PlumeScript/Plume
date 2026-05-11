--[[
This file is part of Plume🪶

Copyright © Erwan Barbedor
Licensed under the MIT License — see LICENSE for details.
]]

--- @opcode
--- Stack 1 from the constants table
--- @param arg2 Constant offset
--! inline
function LOAD_CONSTANT (vm, arg1, arg2)
    --- Stack 1 from constant
    --- arg1: -
    --- arg2: constant offset
    local value = vm.constants[arg2]

    --! to-remove-begin
    if value == nil then
        error("[VM] Try to load a nil value.")
    end
    --! to-remove-end

    _STACK_PUSH(vm.mainStack, value)
end

--- @opcode
--- Stack 1 variable value
--- @param arg1 Scope offset
--- @param arg2 Variable offset
--! inline
function LOAD_LOCAL (vm, arg1, arg2)
    _STACK_PUSH(
        vm.mainStack,
        _STACK_GET_FRAMED(vm.variableStack, arg2 - 1, -arg1)
    )
end

--- @opcode
--- Unstack 1, key
--- Stack 1, key value in target accumulator
--- @param arg1 Scope offset
--! inline
function LOAD_REF (vm, arg1, arg2)
    local key = _STACK_POP(vm.mainStack)
    local pos = _GET_REF_POS(vm, key, arg1)

    if pos then
        _STACK_PUSH(vm.mainStack, _STACK_GET(vm.mainStack, pos))
    else
        _STACK_PUSH(vm.mainStack, vm.plume.obj.empty)
    end
end

--- @opcode
--- Stack 1, `true`
--! inline
function LOAD_TRUE (vm, arg1, arg2)
    _STACK_PUSH(vm.mainStack, true)
end

--- @opcode
--- Stack 1, `false`
--! inline
function LOAD_FALSE (vm, arg1, arg2)
    _STACK_PUSH(vm.mainStack, false)
end

--- @opcode
--- Stack 1, `empty`
--! inline
function LOAD_EMPTY (vm, arg1, arg2)
    _STACK_PUSH(vm.mainStack, vm.empty)
end
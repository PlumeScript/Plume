--[[
This file is part of Plume🪶

Copyright © Erwan Barbedor
Licensed under the MIT License — see LICENSE for details.
]]

--- @opcode
--- Jump to a given instruction
--- @param arg2 jump offset
--! inline
function JUMP (vm, arg1, arg2)
    vm.jump = arg2
end

--- @opcode
--- Unstack 1, and jump to a given instruction if false
--- @param arg2 jump offset
--! inline
function JUMP_IF_NOT (vm, arg1, arg2)
    local test = _STACK_POP(vm.mainStack)
    if not _CHECK_BOOL (vm, test) then
        vm.jump = arg2
    end
end

--- @opcode
--- Unstack 1, and jump to a given instruction if true
--- @param arg2 jump offset
--! inline
function JUMP_IF (vm, arg1, arg2)
    local test = _STACK_POP(vm.mainStack)
    if _CHECK_BOOL (vm, test) then
        vm.jump = arg2
    end
end

--- @opcode
--- Jump to a given instruction if stack top is true
--- @param arg2 jump offset
--! inline
function JUMP_IF_PEEK (vm, arg1, arg2)
    local test = _STACK_GET(vm.mainStack)
    if _CHECK_BOOL (vm, test) then
        vm.jump = arg2
    end
end

--- @opcode
--- Jump to a given instruction if stack top is false
--- @param arg2 jump offset
--! inline
function JUMP_IF_NOT_PEEK (vm, arg1, arg2)
    local test = _STACK_GET(vm.mainStack)
    if not _CHECK_BOOL (vm, test) then
        vm.jump = arg2
    end
end


--- @opcode
--- Unstack 1, and jump to a given instruction if empty
--- @param arg2 jump offset
--! inline
function JUMP_IF_EMPTY (vm, arg1, arg2)
    local test = _STACK_POP(vm.mainStack)
    if test == vm.empty then
        vm.jump = arg2
    end
end

--- @opcode
--- Unstack 1, and jump to a given instruction if any different from empty
--- @param arg2 jump offset
--! inline
function JUMP_IF_NOT_EMPTY (vm, arg1, arg2)
    local test = _STACK_POP(vm.mainStack)
    if test ~= vm.empty then
        vm.jump = arg2
    end
end
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
    if vm.jump > 0 and (vm.err or vm.serr) then
        -- dont erase error jump
    else
        vm.jump = arg2
    end
end

--! inline
function _RESET_JUMP (vm)
    vm.jump = 0-- 0 instead of nil to preserve type
end

--- @opcode
--- Pop 1, and jump to a given instruction if falsy (false or empty)
--- @param arg2 jump offset
--! inline
function JUMP_IF_NOT (vm, arg1, arg2)
    local test = _STACK_POP(vm, vm.mainStack)
    if not _CHECK_BOOL (vm, test) then
        JUMP(vm, 0, arg2)
    end
end

--- @opcode
--- Unstack 1, and jump to a given instruction if true
--- @param arg2 jump offset
--! inline
function JUMP_IF (vm, arg1, arg2)
    local test = _STACK_POP(vm, vm.mainStack)
    if _CHECK_BOOL (vm, test) then
        JUMP(vm, 0, arg2)
    end
end

--- @opcode
--- Jump to a given instruction if stack top is true
--- @param arg2 jump offset
--! inline
function JUMP_IF_PEEK (vm, arg1, arg2)
    local test = _STACK_GET(vm, vm.mainStack)
    if _CHECK_BOOL (vm, test) then
        JUMP(vm, 0, arg2)
    end
end

--- @opcode
--- Jump to a given instruction if stack top is falsy (false or empty), without popping
--- @param arg2 jump offset
--! inline
function JUMP_IF_NOT_PEEK (vm, arg1, arg2)
    local test = _STACK_GET(vm, vm.mainStack)
    if not _CHECK_BOOL (vm, test) then
        JUMP(vm, 0, arg2)
    end
end


--- @opcode
--- Unstack 1, and jump to a given instruction if empty
--- @param arg2 jump offset
--! inline
function JUMP_IF_EMPTY (vm, arg1, arg2)
    local test = _STACK_POP(vm, vm.mainStack)
    if test == vm.plume.obj.empty then
        JUMP(vm, 0, arg2)
    end
end

--- @opcode
--- Unstack 1, and jump to a given instruction if any different from empty
--- @param arg2 jump offset
--! inline
function JUMP_IF_NOT_EMPTY (vm, arg1, arg2)
    local test = _STACK_POP(vm, vm.mainStack)
    if test ~= vm.plume.obj.empty then
        JUMP(vm, 0, arg2)
    end
end

--! inline
function _JUMP_END(vm)
    JUMP(vm, 0, #vm.bytecode)
end
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

    local frameOffset  = _STACK_GET(vm.mainStack.frames, _STACK_POS(vm.mainStack.frames)-arg1)
    local frameTop
    if arg1 == 0 then
        frameTop = _STACK_POS(vm.mainStack)
    else
        frameTop = _STACK_GET(vm.mainStack.frames, _STACK_POS(vm.mainStack.frames)-arg1+1)
    end

    local found
    for i = frameTop, frameOffset, -1 do
        if vm.tagStack[i] == "key" then
            if _STACK_GET(vm.mainStack, i) == key then
                found = true
                _STACK_SET(vm.mainStack, i-1, value)
                break
            end
        end
    end
end
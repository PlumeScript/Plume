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
--- Unstack 1 iterable object and stack 1 iterator.
--- If object as a meta field `next`, it's already and iterator, and will be returned as it.
--- If object as a meta field `iter`, call it.
--- Else, stack the defaut iterator
--- Raise an error if the object isn't a table.
--! inline
function GET_ITER (vm, arg1, arg2)
    local obj = _STACK_POP(vm.mainStack)
    local tobj = _GET_TYPE(vm, obj)
    
    local iter, value, flag, macrocall
    local start = 0
    if tobj == "table" then
        if obj.meta.table.next then
            iter = obj
        else
            iter = obj.meta.table.iter
        end

        
        if iter then
            if iter.type == "luaMacro" then
                value = iter.callable({obj})
            elseif iter.type == "table" then
                value = iter
            elseif iter.type == "macro" then
                macrocall = true
            end
            flag = vm.flag.ITER_CUSTOM
        else
            value = obj.table
            flag = vm.flag.ITER_TABLE
        end

    elseif tobj == "stdIterator" then
        value = obj
        flag = obj.flag
        start = obj.start or start
    else
        _ERROR(vm, vm.plume.error.cannotIterateValue(tobj))
    end

    --! to-remove-begin
    if not vm.err then -- only needed in dev mode, to prevent STACK_PUSH to crash
    --! to-remove-end
        _STACK_PUSH(vm.mainStack, flag)
        _STACK_PUSH(vm.mainStack, start) -- state
        if macrocall then -- call will add the value
            BEGIN_ACC(vm, 0, 0)
            _PUSH_SELF(vm, obj)
            _STACK_PUSH(vm.mainStack, iter)
            _INJECTION_PUSH(vm, vm.plume.ops.CONCAT_CALL, 0, 0)
        else
            _STACK_PUSH(vm.mainStack, value)
        end

    --! to-remove-begin
    end
    --! to-remove-end

    -- GET_ITER is followed by 3 STORE_LOCAL
end

--- @opcode
--- Unstack 1 iterator and call it
--- If empty, jump to for loop end.
--- @param arg2 number Offset of the loop end
--! inline
function FOR_ITER (vm, arg1, arg2)
    local obj   = _STACK_GET_FRAMED(vm.variableStack, 0, 0)
    local state = _STACK_GET_FRAMED(vm.variableStack, 1, 0)
    local flag  = _STACK_GET_FRAMED(vm.variableStack, 2, 0)

    local result, call
    if flag == vm.flag.ITER_TABLE then
        state = state+1

        if state > #obj then
            result = vm.empty
        else
            result = obj[state]
        end
    elseif flag == vm.flag.ITER_SEQ then
        state = state + obj.step
        if state > obj.stop then
            result = vm.empty
        else
            result = state
        end
    elseif flag == vm.flag.ITER_ENUMS then
        state = state+1

        if state > #obj.ref.table then
            result = vm.empty
        else
            -- Could be optimized
            result = vm.plume.obj.table(2, 0)
            result.table[1] = state
            result.table[2] = obj.ref.table[state]
        end
    elseif flag == vm.flag.ITER_ITEMS then
        state = state+1

        if obj.named then
            while tonumber(obj.ref.keys[state]) do
                state = state+1
            end
        end

        if state > #obj.ref.keys then
            result = vm.empty
        else
            -- Could be optimized
            result = vm.plume.obj.table(2, 0)
            result.table[1] = obj.ref.keys[state]
            result.table[2] = obj.ref.table[result.table[1]]
        end
    elseif flag == vm.flag.ITER_CUSTOM then
        local iter = obj.meta.table.next
        if iter.type == "luaMacro" then
            result = iter.callable()
        else
            call = true

            BEGIN_ACC(vm, 0, 0)
            _PUSH_SELF(vm, obj)
            _STACK_PUSH(vm.mainStack, iter)


            _INJECTION_PUSH(vm, vm.plume.ops.JUMP_FOR, 0, arg2)
            _INJECTION_PUSH(vm, vm.plume.ops.CONCAT_CALL, 0, 0)
        end
    else
        error(string.format("[VM] Unkonwn flag '%s'"), flag)
    end

    if not call then
        -- Save state. Offset 1 for local var #2
        _STACK_SET_FRAMED(vm.variableStack, 1, 0, state)

        if result == vm.empty then
            JUMP (vm, 0, arg2)
        else
            _STACK_PUSH(vm.mainStack, result)
        end
    end
end

--- @opcode
--- If stack top is empty, pop it and jump.
--- Else, do nothing
--- @param arg2 jump offset
--! inline
function JUMP_FOR (vm, arg1, arg2)
    local test = _STACK_GET(vm.mainStack)
    if not _CHECK_BOOL (vm, test) then
        _STACK_POP(vm.mainStack)
        JUMP(vm, 0, arg2)
    end
end

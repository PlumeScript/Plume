--[[
This file is part of Plume🪶

Copyright © Erwan Barbedor
Licensed under the MIT License — see LICENSE for details.
]]

--- @opcode
--! inline
function PUSH_CONTEXT(vm, arg1, arg2)
    local values = _STACK_POP(vm, vm.mainStack)

    local cache = {}
    _STACK_PUSH(vm, vm.contextStackCache, cache)
    for _, var in ipairs(values.keys) do
        local value = values.table[var]

        if type(var) ~= "table" or var.type ~= "context" then
            _ERROR(vm, vm.plume.error.wrongContextType(var))
        else
            var:push(value)
            table.insert(cache, var)
        end 
    end
end

--- @opcode
--! inline
function POP_CONTEXT(vm, arg1, arg2)
    local cache = _STACK_POP(vm, vm.contextStackCache)
    for _, var in ipairs(cache) do
        var:pop()
    end
end
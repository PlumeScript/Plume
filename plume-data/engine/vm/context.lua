--[[
This file is part of Plume🪶

Copyright © Erwan Barbedor
Licensed under the MIT License — see LICENSE for details.
]]

--- @opcode
--! inline
function CREATE_CONTEXT(vm, arg1, arg2)
	local defaultValue = _STACK_POP(vm, vm.mainStack)
    _STACK_PUSH(vm, vm.mainStack, vm.plume.obj.context(defaultValue))
end

--- @opcode
--! inline
function PUSH_CONTEXT(vm, arg1, arg2)
    local values = _STACK_POP(vm, vm.mainStack)

    local cache = {}
    _STACK_PUSH(vm, vm.contextStackCache, cache)
    -- add: check if is a table
    for _, var in ipairs(values.keys) do
        local value = values.table[var]
        var:push(value)
        table.insert(cache, var)
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

--- @opcode
--! inline
function LOAD_CONTEXT(vm, arg1, arg2)
    local default = _STACK_POP(vm, vm.mainStack)
    local name    = _STACK_POP(vm, vm.mainStack)
    _STACK_PUSH(vm, vm.mainStack, _LOAD_CONTEXT(vm, name, false, default))
end
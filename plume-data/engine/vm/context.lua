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

--- Will be removed in edition Owl #614, #817
--- @opcode
--! inline
function COMPAT_CONTEXT_GLOBAL_CACHE(vm, arg1, arg2)

    local offset = arg2
    local name   = _STACK_POP(vm, vm.mainStack)
    
    if vm.globalStackCache[name] then
        _STACK_SET(vm, vm.variableStack, offset, vm.globalStackCache[name])
    else  
        vm.globalStackCache[name] = _STACK_GET(vm, vm.variableStack, offset)
    end
end
---------------------------------------------

--- @opcode
--! inline
function PUSH_CONTEXT(vm, arg1, arg2)
    local values = _STACK_POP(vm, vm.mainStack)

    local cache = {}
    _STACK_PUSH(vm, vm.contextStackCache, cache)
    for _, var in ipairs(values.keys) do
        local value = values.table[var]

        --- Will be removed in edition Owl #614, #817
        if type(var) == "string" then
            if not vm.globalStackCache[var] then
                vm.globalStackCache[var] = vm.plume.obj.context()
            end
            var = vm.globalStackCache[var]
            vm.plume.warning.runtimeWarning("From edition 'Owl', string-based contextual key will raise an error.", "Use `with $x: value` instead of `with x: value`", vm.runtime, vm.ip, {614, 817})
        ---------------------------------------------
        elseif type(var) ~= "table" or var.type ~= "context" then
            -- error
        end


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
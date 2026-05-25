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
    local value = _STACK_POP(vm, vm.mainStack)
    local name  = _STACK_POP(vm, vm.mainStack)
    _STACK_PUSH(vm, vm.contextStack, {name=name, value=value})
end

--! inline
function _LOAD_CONTEXT(vm, name, nocheck, default)
    local top = _STACK_POS(vm, vm.contextStack)
    for i = top, 1, -1 do
        local frame = _STACK_GET(vm, vm.contextStack, i)
        if frame.name == name then
            return frame.value
        end
    end
    if default then
        return default
    end
    if not nocheck then
        vm.plume.warning.runtimeWarning(
            "Empty context variable",
            "Consider declaring it with a default value: `let context var = <value>`",
            vm.runtime, vm.ip, {526}
        )
    end
    return vm.empty
end

--- @opcode
--! inline
function LOAD_CONTEXT(vm, arg1, arg2)
    local default = _STACK_POP(vm, vm.mainStack)
    local name    = _STACK_POP(vm, vm.mainStack)
    _STACK_PUSH(vm, vm.mainStack, _LOAD_CONTEXT(vm, name, false, default))
end

--- @opcode
--! inline
function POP_CONTEXT(vm, arg1, arg2)
    _STACK_POP(vm, vm.contextStack)
end
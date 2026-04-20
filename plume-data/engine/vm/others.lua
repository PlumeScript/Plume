--[[
This file is part of Plume🪶

Copyright © Erwan Barbedor
Licensed under the MIT License — see LICENSE for details.
]]

--- @opcode
--- Switch two top stack values
--! inline
function SWITCH (vm, arg1, arg2)
    local x = _STACK_POP(vm.mainStack)
    local y = _STACK_POP(vm.mainStack)
    _STACK_PUSH(vm.mainStack, x)
    _STACK_PUSH(vm.mainStack, y)
    
end

--- @opcode
--- Stack 1 more top stack value
--! inline
function DUPLICATE (vm, arg1, arg2)
    _STACK_PUSH(vm.mainStack, _STACK_GET(vm.mainStack))
end
--[[
This file is part of Plume🪶

Copyright © Erwan Barbedor
Licensed under the MIT License — see LICENSE for details.
]]

--- @opcode
--- Create a new frame and set all it's variable to empty
--- @param arg1 number Number of local variables already stacked
--- @param arg2 number Number of local variables
--! inline
function ENTER_SCOPE (vm, arg1, arg2)
    _STACK_PUSH(vm, 
        vm.variableStack.frames,
        _STACK_POS(vm, vm.variableStack) + 1 - arg1
    )
    
    for i = 1, arg2-arg1 do
        _STACK_PUSH(vm, vm.variableStack, vm.empty)
    end
end

--- @opcode
--- Close a frame
--! inline
function LEAVE_SCOPE (vm, arg1, arg2)
    _STACK_POP_FRAME(vm, vm.variableStack)
end

--- @opcode
--! inline
function RETURN_FILE(vm, arg1, arg2)
    LEAVE_SCOPE(vm)
    _STACK_POP(vm, vm.fileStack)
    _POP_CALLSTACK(vm)

    if _STACK_POS(vm, vm.fileStack) == 0 then
        _INJECTION_PUSH(vm, vm.plume.ops.END, 0, 0) -- last file, end the program
    else
        JUMP(vm, 0, _STACK_POP(vm, vm.macroStack)) -- return in the previous position
    end
end

--- @opcode
--! inline
function FILE_INIT_PARAMS(vm, arg1, arg2)
    local params = vm.fileParams
    if params then
        for _, paramInfos in ipairs(params) do
            _STACK_SET_FRAMED(vm, vm.variableStack, paramInfos.offset-1, 0, paramInfos.value)
        end
        vm.fileParams = nil
    end
end

--- @opcode
--! inline
function RAISE(vm, arg1, arg2)
    local msg = _STACK_POP(vm, vm.mainStack)
    _ERROR (vm, msg)
end
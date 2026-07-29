--[[
This file is part of Plume🪶

Copyright © Erwan Barbedor
Licensed under the MIT License — see LICENSE for details.
]]

--- Add a macro to the callstack, with current ip
---@param vm VM The virtual machine instance.
---@param macro table The called macro
--! inline
function _PUSH_CALLSTACK(vm, macro, safe)
    local callinfos = {runtime=vm.runtime, macro=macro, ip=vm.ip, safe=safe}
    if vm.ip == vm.plume.sops.CONCAT_CALL or vm.ip == vm.plume.sops.CONCAT_CALL_SAFE then --recursive call
        callinfos.base = #vm.runtime.callstack
        callinfos.ip = _STACK_GET(vm, vm.recursiveStack)
    end

    table.insert(vm.runtime.callstack, callinfos)
    if #vm.runtime.callstack>1000 then
        _ERROR (vm, vm.plume.error.stackOverflow())
    end
end

--- Remove a macro from callstack
---@param vm VM The virtual machine instance.
--! inline
function _POP_CALLSTACK(vm)
    local call = table.remove(vm.runtime.callstack)

    if call and call.safe then
        local result = _STACK_POP(vm, vm.mainStack)
        local safeResult = vm.plume.obj.table(0, 2)
        safeResult:setItem("success", true)
        safeResult:setItem("result", result)
        _STACK_PUSH(vm, vm.mainStack, safeResult)
    end

    if call and call.base then
        if call.base == #vm.runtime.callstack then
            _JUMP_END(vm)
            return true
        end
    end
end

--- @opcode
--- @param arg1 Flag, 1 for a validator flag
--- @param arg2 Flag, 1 for the safe mode
--- Take the stack top to call, with all elements of the current frame as parameters.
--- Stack the call result (or empty if nil)
--- Handle macros and luaMacro
--! inline
function CONCAT_CALL (vm, arg1, arg2)
    local tocall = _STACK_POP(vm, vm.mainStack)
    local t = _GET_TYPE(vm, tocall)
    local self


    -- Table can be called with, if exists, the meta-field call
    if t == "table" then
        local mvalidate = tocall:getMetaItem("validate")
        local mcall     = tocall:getMetaItem("call")
        if arg1==1 and mvalidate then
            self = tocall
            tocall = mvalidate
            t = tocall.type
        elseif mcall then
            self = tocall
            tocall = mcall
            t = tocall.type
        end
    end
    
    -- Macro
    if t == "macro"  then
        if self then
            _PUSH_SELF(vm, self)
        end

        _CALL_MACRO(vm, tocall, arg1==1, arg2==1)
        _STACK_PUSH(vm, vm.closureStack, {})

    elseif t == "closure" then
        if self then
            _PUSH_SELF(vm, self)
        end

        _CALL_MACRO(vm, tocall.macro, arg1==1, arg2==1)
        _STACK_PUSH(vm, vm.closureStack, tocall.upvalues)

    -- Std functions defined in lua or user lua functions
    elseif t == "luaMacro" then
        CONCAT_TABLE(vm)
        _PUSH_CALLSTACK(vm, tocall, arg2==1)

        local args        = _STACK_POP(vm, vm.mainStack)
        local currentFile = _STACK_GET(vm, vm.fileStack)

        _SAVE_SCALAR(vm)
        local success, result, isHosted = tocall.callable (args, vm, currentFile)
        _UPDATE_SCALAR(vm)

        if success then
            
            if result == nil then
                result = vm.plume.obj.empty
            end
            
            _STACK_PUSH(vm, vm.mainStack, result)
            if isHosted then
                HOST_UPDATE(vm, 0, 0)
            else
                _POP_CALLSTACK(vm)
            end
            
        else
            _ERROR(vm, result)
        end
    -- Contextal variables
    elseif t == "context" then
        CONCAT_TABLE(vm)
        _STACK_POP(vm, vm.mainStack) -- Remove args
        _STACK_PUSH(vm, vm.mainStack, tocall:get())

    -- @table ... end just return the accumulated table
    elseif tocall == vm.plume.std.Table then
        CONCAT_TABLE(vm)

    -- FORCE_FRAGMENT do exactly the same thing as tostring
    elseif tocall == vm.plume.std.String then

        local value = _STACK_POP(vm, vm.mainStack)
        _STACK_POP_FRAME(vm, vm.mainStack)
        _STACK_PUSH(vm, vm.mainStack, value)
        -- Should check for to many arguments, instead of ignoring them
        _INJECTION_PUSH(vm, vm.plume.ops.CHECK_IS_TEXT, 0, 0) -- wait for remove: endless rec (use CONCAT_CALL)
        _INJECTION_PUSH(vm, vm.plume.ops.FORCE_FRAGMENT, 0, 0)

    elseif tocall == vm.plume.std.attempt then
        local macro = _STACK_GET_FRAMED(vm, vm.mainStack, 0)
        local tmacro = _GET_TYPE(vm, macro)

        if tmacro ~= "macro" and tmacro ~= "closure" and tmacro ~= "luaMacro" then
            _ERROR(vm, string.format("`attempt` first argument must be a macro, not a '%s'.", tmacro))
        end

        -- Macro should be at the end
        local frameBegin = _STACK_GET(vm, vm.mainStack.frames)
        local frameEnd   = _STACK_POS(vm, vm.mainStack)
        for i = frameBegin, frameEnd-1 do
            vm.mainStack[i] = vm.mainStack[i+1]
        end
        vm.mainStack[frameEnd] = macro
        
        _PUSH_CALLSTACK(vm, tocall, arg2==1)
        _CONCAT_CALL_SAFE_REC(vm)
        _POP_CALLSTACK(vm)
    elseif tocall == vm.plume.std.import then
        local args = CONCAT_TABLE(vm)
        _PUSH_CALLSTACK(vm, tocall, arg2==1)
        STD_IMPORT(vm)
    else
        _ERROR (vm, vm.plume.error.cannotCallValue(t))
    end
end

---@param vm VM The virtual machine instance.
---@param chunk table The function chunk to call.
---@param bool isValidator
--! inline
function _CALL_MACRO(vm, chunk, isValidator, safe)
    if isValidator and chunk.positionalParamCount ~= 1 then
        _ERROR(vm, vm.plume.error.wrongValidatorArgsCount(chunk, chunk.positionalParamCount))
    else   
        ENTER_SCOPE(vm, 0, chunk.localsCount) -- Create a new scope

        -- Distribute arguments to locals and get the overflow table
        local variadicTable, tomanyPositionnalCounter, capturedCount, unknownNamed = _CONCAT_TABLE(
            vm,
            chunk.positionalParamCount,
            chunk.namedParamOffset,
            chunk.variadicOffset
        )

        if tomanyPositionnalCounter>0 then
            _ERROR(vm, vm.plume.error.wrongArgsCount(
                chunk,
                chunk.positionalParamCount+tomanyPositionnalCounter,
                chunk.positionalParamCount
            ))
        elseif capturedCount < chunk.positionalParamCount then
            _ERROR(vm, vm.plume.error.wrongArgsCount(
                chunk,
                capturedCount,
                chunk.positionalParamCount
            ))
        elseif unknownNamed then
            _ERROR(vm, vm.plume.error.unknownParameter(unknownNamed, chunk))
        else
            -- If the chunk expects a variadic argument, assign the table to the specific register
            if chunk.variadicOffset then
                _STACK_SET_FRAMED(vm, vm.variableStack, chunk.variadicOffset - 1, 0, variadicTable)
            end
            _PUSH_CALLSTACK(vm, chunk, safe)
            _STACK_POP_FRAME(vm, vm.mainStack)        -- Clean stack from arguments
            _STACK_PUSH(vm, vm.macroStack, vm.ip + 1) -- Set the return pointer
            JUMP(vm, 0, chunk.offset)             -- Jump to macro body  
        end
    end
end

--- @opcode
--- Return from the current macro call.
--- Closes the macro scope, pops the closure stack, pops the callstack,
--- and jumps back to the saved return address.
--! inline
function RETURN(vm, arg1, arg2)
    LEAVE_SCOPE(vm, 0, 0) -- close macro scope
    _STACK_POP(vm, vm.closureStack)
    local exit = _POP_CALLSTACK(vm)
    local ret  = _STACK_POP(vm, vm.macroStack)
    if not exit then
        JUMP(vm, 0, ret) -- return in the previous position
    end
end

--- @opcode
--- Receive the next value from a host callback context.
--- Pops the callback result from the stack; if it is falsy, ends the host call.
--- Otherwise handles jump precedence over injected instructions.
--! inline
function HOST_NEXT(vm)
    local value   = _STACK_POP(vm, vm.mainStack)
    local context = _STACK_GET(vm, vm.mainStack)

    local success, result = context:HOST_NEXT(value)

    if not success then
        _ERROR(vm, result)
    -- An injection takes precedence over a JUMP.
    -- This results in the JUMP RETURN being overwritten
    -- by a new JUMP to the macro to be called, unless the jump is forced here.
    elseif vm.jump>0  then
        if vm.jump == #vm.bytecode then
            -- Pretty dirty.
            -- The implementation of injections is a bit shaky
            -- and doesn't handle the end of bytecode very well.     
            _INJECTION_PUSH(vm, vm.plume.ops.END,   0, 0) -- wait for remove: #1050
            _INJECTION_PUSH(vm, vm.plume.ops.HOST_UPDATE, 0, 0) -- Reinject HOST_UPDATE to clean host
        else
            vm.ip = vm.jump-1
            _RESET_JUMP(vm)
        end
    end
end

--- @opcode
--- Resume a host callback context after its macro call completes.
--- If the context has a pending callback, re-injects HOST_NEXT + CONCAT_CALL.
--- Otherwise pops the callstack and pushes the context's return value.
--! inline
function HOST_UPDATE(vm)
    local context = _STACK_GET(vm, vm.mainStack)

    local success, result = context:HOST_UPDATE()
    if not success then
        _ERROR(vm, result)
    elseif context.PLUME_CALLBACK then
        BEGIN_ACC(vm, 0, 0)
        for _, value in ipairs(context.PLUME_CALLBACK_ARGS or {}) do
            _STACK_PUSH(vm, vm.mainStack, value)
        end

        _STACK_PUSH(vm, vm.mainStack, context.PLUME_CALLBACK)
        
        _INJECTION_PUSH(vm, vm.plume.ops.HOST_UPDATE, 0, 0) -- wait for remove: #1050
        _INJECTION_PUSH(vm, vm.plume.ops.HOST_NEXT,   0, 0)
        _INJECTION_PUSH(vm, vm.plume.ops.CONCAT_CALL, 0, 0)
    else
        _POP_CALLSTACK(vm)
        _STACK_POP(vm, vm.mainStack)
        _STACK_PUSH(vm, vm.mainStack, context.RETURN_VALUE or vm.plume.obj.empty)
    end
end
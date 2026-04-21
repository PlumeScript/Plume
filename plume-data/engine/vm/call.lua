--[[
This file is part of Plume🪶

Copyright © Erwan Barbedor
Licensed under the MIT License — see LICENSE for details.
]]

--- Add a macro to the callstack, with current ip
---@param vm VM The virtual machine instance.
---@param macro table The called macro
--! inline
function _PUSH_CALLSTACK(vm, macro)
    table.insert(vm.runtime.callstack, {runtime=vm.runtime, macro=macro, ip=vm.ip})
    if #vm.runtime.callstack>1000 then
        _ERROR (vm, vm.plume.error.stackOverflow())
    end
end

--- Remove a macro from callstack
---@param vm VM The virtual machine instance.
--! inline
function _POP_CALLSTACK(vm)
    table.remove(vm.runtime.callstack)
end

--- @opcode
--- @param arg1 Flag, 1 for a validator flag
--- Take the stack top to call, with all elements of the current frame as parameters.
--- Stack the call result (or empty if nil)
--- Handle macros and luaMacro
--! inline
function CONCAT_CALL (vm, arg1, arg2)
    local tocall = _STACK_POP(vm.mainStack)
    local t = _GET_TYPE(vm, tocall)
    local self

    -- Table can be called with, if exists, the meta-field call
    if t == "table" then
        if arg1==1 and tocall.meta and tocall.meta.table.validate then
            self = tocall
            tocall = tocall.meta.table.validate
            t = tocall.type
        elseif tocall.meta and tocall.meta.table.call then
            self = tocall
            tocall = tocall.meta.table.call
            t = tocall.type
        end
    end

    -- Macro
    if t == "macro"  then
        if self then
            _PUSH_SELF(vm, self)
        end

        _CALL_MACRO(vm, tocall, arg1==1)
        _STACK_PUSH(vm.closureStack, {})

    elseif t == "closure" then
        if self then
            _PUSH_SELF(vm, self)
        end

        _CALL_MACRO(vm, tocall.macro)
        _STACK_PUSH(vm.closureStack, tocall.upvalues)

    -- Std functions defined in lua or user lua functions
    elseif t == "luaMacro" then
        CONCAT_TABLE(vm)
        _PUSH_CALLSTACK(vm, tocall)
        
        local success, result, isHosted = tocall.callable (_STACK_POP(vm.mainStack), vm.runtime, _STACK_GET(vm.fileStack), vm.ip)

        if success then
            
            if result == nil then
                result = vm.empty
            end
            
            _STACK_PUSH(vm.mainStack, result)
            if isHosted then
                _INJECTION_PUSH(vm, vm.plume.ops.HOST_UPDATE, 0, 0)
            else
                _POP_CALLSTACK(vm)
            end
        else
            _ERROR(vm, result)
        end

    -- Some harcoded std functions
    elseif t == "stdMacro" then
        local args = CONCAT_TABLE(vm)
        if #args.table < tocall.minArgs or #args.table > tocall.maxArgs then
            _ERROR(vm, vm.plume.error.wrongArgsCountStd(tocall.name, #args.table, tocall.minArgs, tocall.maxArgs))
        end
        
        _PUSH_CALLSTACK(vm, tocall)
        _INJECTION_PUSH(vm, tocall.opcode, 0, 0)

    -- @table ... end just return the accumulated table
    elseif tocall == vm.plume.std.Table then
        CONCAT_TABLE(vm)

    -- CHECK_IS_TEXT do exactly the same thing as tostring
    elseif tocall == vm.plume.std.String then

        local value = _STACK_POP(vm.mainStack)
        _STACK_POP_FRAME(vm.mainStack)
        _STACK_PUSH(vm.mainStack, value)
        -- Should check for to many arguments, instead of ignoring them
        _INJECTION_PUSH(vm, vm.plume.ops.CHECK_IS_TEXT, 0, 0)

    else
        _ERROR (vm, vm.plume.error.cannotCallValue(t))
    end
end

---@param vm VM The virtual machine instance.
---@param chunk table The function chunk to call.
---@param bool isValidator
--! inline
function _CALL_MACRO(vm, chunk, isValidator)
    if isValidator and chunk.positionalParamCount ~= 1 then
        _ERROR(vm, vm.plume.error.wrongValidatorArgsCount(chunk, chunk.positionalParamCount))
    else

        local allocationCount = chunk.positionalParamCount + chunk.namedParamCount

        if chunk.variadicOffset then
            allocationCount = allocationCount + 1
        end
        
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
                _STACK_SET_FRAMED(vm.variableStack, chunk.variadicOffset - 1, 0, variadicTable)
            end

            _PUSH_CALLSTACK(vm, chunk)
            _STACK_POP_FRAME(vm.mainStack)        -- Clean stack from arguments
            _STACK_PUSH(vm.macroStack, vm.ip + 1) -- Set the return pointer
            JUMP(vm, 0, chunk.offset)             -- Jump to macro body  
        end
    end
end

--- @opcode
--! inline
function RETURN(vm, arg1, arg2)
    LEAVE_SCOPE(vm, 0, 0) -- close macro scope
    _STACK_POP(vm.closureStack)
    table.remove(vm.runtime.callstack)
    JUMP(vm, 0, _STACK_POP(vm.macroStack)) -- return in the previous position
end

--- @opcode
--! inline
function HOST_NEXT(vm)
    local value   = _STACK_POP(vm.mainStack)
    local context = _STACK_GET(vm.mainStack)

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
            _INJECTION_PUSH(vm, vm.plume.ops.END,   0, 0)
            _INJECTION_PUSH(vm, vm.plume.ops.HOST_UPDATE, 0, 0) -- Reinject HOST_UPDATE to clean host
        else
            vm.ip = vm.jump-1
            vm.jump = 0
        end
    end
end

--- @opcode
--! inline
function HOST_UPDATE(vm)
    local context = _STACK_GET(vm.mainStack)

    local success, result = context:HOST_UPDATE()
    if not success then
        _ERROR(vm, result)
    elseif context.PLUME_CALLBACK then
        BEGIN_ACC(vm, 0, 0)
        for _, value in ipairs(context.PLUME_CALLBACK_ARGS or {}) do
            _STACK_PUSH(vm.mainStack, value)
        end

        _STACK_PUSH(vm.mainStack, context.PLUME_CALLBACK)
        
        _INJECTION_PUSH(vm, vm.plume.ops.HOST_UPDATE, 0, 0)
        _INJECTION_PUSH(vm, vm.plume.ops.HOST_NEXT,   0, 0)
        _INJECTION_PUSH(vm, vm.plume.ops.CONCAT_CALL, 0, 0)
    else
        _POP_CALLSTACK(vm)
        _STACK_POP(vm.mainStack)
        _STACK_PUSH(vm.mainStack, context.RETURN_VALUE or vm.empty)
    end
end
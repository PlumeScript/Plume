--[[
This file is part of Plume🪶

Copyright © Erwan Barbedor
Licensed under the MIT License — see LICENSE for details.
]]

--- @param x any
--- @return string Type of x
--! inline
function _GET_TYPE(vm, x)
    return type(x) == "table" and (x == vm.plume.obj.empty and "empty" or x.type) or (type(x) == "cdata" and x.type) or type(x)
end

--- Throw an error
--- @param msg string
--- @return nil
function _ERROR (vm, msg)
    local safeCallIndex
    for i = #vm.runtime.callstack, 1, -1 do
        local call = vm.runtime.callstack[i]
        if call.safe then
            safeCallIndex = i
        end
    end

    -- Logic duplication with _POP_CALLSTACK - see #1084
    if safeCallIndex then
        local returnRun = false
        for i=#vm.runtime.callstack, safeCallIndex, -1 do
            local call = table.remove(vm.runtime.callstack)
            if call and call.base then
                if call.base == #vm.runtime.callstack then
                    returnRun = true
                    _JUMP_END(vm)
                end
            end
            LEAVE_SCOPE(vm, 0, 0)
            _STACK_POP(vm, vm.closureStack)
            _STACK_POP(vm, vm.macroStack)
        end
        local safeResult = vm.plume.obj.table(0, 2)
        safeResult:setItem("success", false)
        safeResult:setItem("result", msg)
        if not returnRun then
            RETURN(vm)
        end
        _STACK_PUSH(vm, vm.mainStack, safeResult)
    else
        vm.err = msg
        vm.errip = vm.ip
        _JUMP_END(vm)
    end
end

--- @param x any
--- @return any|false Return false if x is empty, else x it self.
--! inline
function _CHECK_BOOL (vm, x)
    if x == vm.plume.obj.empty then
        return false
    end
    return x
end

--- Find offset corresponding to a key in the current building table
--- @param key string
--- @param offset number
--! inline
function _GET_REF_POS(vm, key, offset)
    offset = offset-1 -- frames start at 0

    local frameBottom
    if offset == 0 then
        frameBottom = 1
    else
        frameBottom = _STACK_GET(vm, vm.mainStack.frames, offset)
    end
    
    local frameTop
    if offset == _STACK_POS(vm, vm.mainStack.frames)-1 or offset==0 then
        frameTop = _STACK_POS(vm, vm.mainStack)+1
    else
        frameTop = _STACK_GET(vm, vm.mainStack.frames, offset+1)
    end
    
    --! to-remove-begin
    if not frameTop or frameTop <= 0 then
        _ERROR(vm, "[VM] Wrong frameTop, cannot find current ref.")
        return
    end
    if not frameBottom or frameBottom <= 0 then
        _ERROR(vm, "[VM] Wrong frameBottom, cannot find current ref.")
        return
    end
    --! to-remove-end
    
    for i = frameTop-1, frameBottom, -1 do
        if vm.tagStack[i] == "key" then
            if _STACK_GET(vm, vm.mainStack, i) == key then
                return i-1 -- Value is just before the key
            end
        end
    end
end

--! inline
function _GET_CURRENT_FILE(vm)
    local lastfile
    local files = vm.runtime.files
    local ip    = vm.ip
    for _, file in ipairs(files) do
        if file.offset then
            if file.offset <= ip then
                if not lastfile or file.offset > lastfile.offset then
                    lastfile = file
                end
            end
        end
    end

    return lastfile
end

--! inline
function _FINAL_CHECKS (vm)
    if vm.mainStack.pointer > 1 then
        return false, "[Internal Error] To many elements on stack."
    elseif vm.mainStack.pointer == 0 then
        return false, "[Internal Error] Stack empty."
    end

    return true
end  

--! inline
function _SAVE_SCALAR(vm)
    --! save-scalar
end

--! inline
function _UPDATE_SCALAR(vm)
    --! update-scalar
end
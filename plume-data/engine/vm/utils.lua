--[[
This file is part of Plume🪶

Copyright © Erwan Barbedor
Licensed under the MIT License — see LICENSE for details.
]]

--- @param x any
--- @return string Type of x
--! inline
function _GET_TYPE(vm, x)
    return type(x) == "table" and (x == vm.empty and "empty" or x.type) or (type(x) == "cdata" and x.type) or type(x)
end

--- Throw an error
--- @param msg string
--- @return nil
--! inline-keepret
function _ERROR (vm, msg)
    vm.err = msg
end

--- @param x any
--- @return any|false Return false if x is empty, else x it self.
--! inline
function _CHECK_BOOL (vm, x)
    if x == vm.empty then
        return false
    end
    return x
end

--- Find offset corresponding to a key in the current building table
--- @param key string
--- @param offset number
--! inline
function _GET_REF_POS(vm, key, offset)
    local frameOffset  = _STACK_GET(vm.mainStack.frames, _STACK_POS(vm.mainStack.frames)-offset)
    local frameTop
    if offset == 0 then
        frameTop = _STACK_POS(vm.mainStack)
    else
        frameTop = _STACK_GET(vm.mainStack.frames, _STACK_POS(vm.mainStack.frames)-offset+1)
    end

    for i = frameTop, frameOffset, -1 do
        if vm.tagStack[i] == "key" then
            if _STACK_GET(vm.mainStack, i) == key then
                return i-1
            end
        end
    end
end
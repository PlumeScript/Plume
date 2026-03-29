--[[This file is part of Plume

Plume🪶 is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, version 3 of the License.

Plume🪶 is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with Plume🪶.
If not, see <https://www.gnu.org/licenses/>.
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
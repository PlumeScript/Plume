--[[
This file is part of Plume🪶

Copyright © Erwan Barbedor
Licensed under the MIT License — see LICENSE for details.
]]

--- @opcode
--- Create a new accumulation frame
--! inline
function BEGIN_ACC(vm, arg1, arg2)
    _STACK_PUSH(vm, 
        vm.mainStack.frames,
        vm.mainStack.pointer+1
    )
end

--- Close the current frame
--! inline
function _END_ACC (vm)
    _STACK_POP(vm, vm.mainStack.frames)
end

--! inline
function _MAKE_FRAGMENT(vm, start, count)
    local fragment = vm.plume.obj.fragment(count)
    for i = 1, count do
        fragment[i] = _STACK_GET(vm, vm.mainStack, start+i-1)
    end
    return fragment
end

--- @opcode
--- Concatenate all values in the current frame into a single fragment.
--- Pops every value down to the frame marker, concatenates them, and pushes the result.
--- Small, flat sequences of strings/numbers are optimized via direct `table.concat`;
--- larger or nested sequences produce a *fragment* (a lazy array of parts).
--! inline
function CONCAT_TEXT (vm, arg1, arg2)
    local start = _STACK_GET(vm, vm.mainStack.frames)
    local stop  = _STACK_POS(vm, vm.mainStack)
    local count = stop - start + 1
    local fragment

    local CONCAT_COUNT_LIMIT  = 8
    local CONCAT_LENGTH_LIMIT = 64

    --! to-remove-begin
    -- No optimisation in debug mode
    CONCAT_COUNT_LIMIT = 0
    --! to-remove-end

    if count == 0 then
        fragment = ""
    elseif count == 1 then
        fragment = _STACK_GET(vm, vm.mainStack, start)
    elseif count <= CONCAT_COUNT_LIMIT then
        local directConcat = true
        local length = 0
        for i = start, stop do
            local item = _STACK_GET(vm, vm.mainStack, i)
            if _GET_TYPE(vm, item) == "fragment" then
                directConcat = false
                break
            else
                length = length + #item
            end
        end
        directConcat = directConcat and length <= CONCAT_LENGTH_LIMIT
        if directConcat then
            fragment = table.concat(vm.mainStack, "", start, stop)
        else
            fragment = _MAKE_FRAGMENT(vm, start, count)
        end
    else
        fragment = _MAKE_FRAGMENT(vm, start, count)
    end
    _STACK_MOVE(vm, vm.mainStack, start)
    _STACK_SET(vm, vm.mainStack, start, fragment)
    _END_ACC(vm)
end

--- @opcode
--- Recursively flatten a fragment on stack top into a single string.
--- If the value is not a fragment, does nothing.
--! inline
function FORCE_FRAGMENT (vm, arg1, arg2)
    local fragment = _STACK_GET(vm, vm.mainStack)

    if _GET_TYPE(vm, fragment) == "fragment" then
        local result        = {}
        local stackFragment = {fragment}
        local stackIndex    = {}
        local depth         = 0

        while #stackFragment > 0 do
            depth = #stackFragment
            local top = table.remove(stackFragment)
            local quickExit = false
            for i=(stackIndex[depth] or 1), #top do
                local item = top[i]
                if type(item) == "table" then -- by construction, must be a fragment
                    stackIndex[depth] = i+1
                    table.insert(stackFragment, top)
                    table.insert(stackFragment, item)
                    quickExit = true
                    break
                else
                    table.insert(result, item)
                end
            end
            if not quickExit then
                stackIndex[depth] = 1
            end
        end
        _STACK_POP(vm, vm.mainStack)
        _STACK_PUSH(vm, vm.mainStack, table.concat(result))
    end
end

--- @opcode
--- Make a table from elements of the current frame
--- Unstack all element in current frame, remove the last frame.
--- Make a new table
--- First unstacked element must be a table, containing in order key, value, ismeta to insert in the new table
--- All following elements are appended to the new table.
--! inline
function CONCAT_TABLE(vm)
    -- Treat all arguments as variadic by asking for 0 positional variables and 0 named variables
    local resultTable = _CONCAT_TABLE(vm, 0, nil, true)

    _STACK_POP_FRAME(vm, vm.mainStack) -- Clean stack from arguments
    _STACK_PUSH(vm, vm.mainStack, resultTable) -- Push the resulting table onto the stack

    return resultTable
end

---@param posParamCount integer The number of expected positional parameters (0 for none).
---@param namedParamOffset table|nil A map of named parameters to their register offsets (nil for none).
---@return table The variadic table object containing surplus/variadic arguments.
--! inline
function _CONCAT_TABLE(vm, posParamCount, namedParamOffset, variadic)
    local argsOffset   = 1
    
    local frameOffset  = _STACK_GET(vm, vm.mainStack.frames)
    local bufferOffset = frameOffset
    local mainStackTop = _STACK_POS(vm, vm.mainStack)

    local variadicTable
    -- Heuristic allocation: assume worst case (all items are part of the table)
    if variadic then
        local max = mainStackTop - bufferOffset + 1
        variadicTable = vm.plume.obj.table(max, max / 2)
    end

    local tomanyPositionalCounter = 0
    local capturedCount = 0
    local unknownNamed

    while bufferOffset <= mainStackTop do
        local tag = vm.tagStack[bufferOffset+1]
        local value = _STACK_GET(vm, vm.mainStack, bufferOffset)
        -- Positional Argument
        if tag == nil then
            if argsOffset <= posParamCount then
                -- Assign to local variable register
                _STACK_SET_FRAMED(vm, vm.variableStack, argsOffset-1, 0, value)
                capturedCount = capturedCount+1
            elseif variadicTable then
                -- Surplus → Insert into variadic table
                variadicTable:addItem(value)
            else
                tomanyPositionalCounter = tomanyPositionalCounter+1
            end
            argsOffset = argsOffset + 1

        -- Named Argument or Meta Key
        else
            bufferOffset = bufferOffset + 1
            local key = _STACK_GET(vm, vm.mainStack, bufferOffset)
            -- Check if this key corresponds to a declared named parameter
            local argOffset = namedParamOffset and (namedParamOffset)[key]
            if argOffset then
                if tag == "key" then
                    -- Assign to local variable register
                    _STACK_SET_FRAMED(vm, vm.variableStack, argOffset-1, 0, value)
                else
                    _ERROR(vm, vm.plume.error.cannotUseMetaKey)
                end
            else
                -- Unknown key → Insert into variadic table
                if variadicTable then
                    if tag == "key" then
                        variadicTable:setItem(key, value)
                    elseif tag == "metakey" then
                        variadicTable:setMetaItem(key, value)
                    end
                elseif not unknownNamed then -- should capture all unknown?
                    unknownNamed = key
                end
            end
            
            vm.tagStack[bufferOffset] = nil -- Clean tagstack for the key
        end
        bufferOffset = bufferOffset + 1
    end

    return variadicTable, tomanyPositionalCounter, capturedCount, unknownNamed
end

--- @opcode
--- Check if stack top can be concatened
--- Get stack top. If neither empty, number or string, try
--- to convert it, else throw an error.
--! inline
function CHECK_IS_TEXT (vm, arg1, arg2)
    local value = _STACK_GET(vm, vm.mainStack)
    local t     = _GET_TYPE(vm, value)

    if value == vm.plume.obj.empty then
        _STACK_SET(vm, vm.mainStack, _STACK_POS(vm, vm.mainStack), "")
    elseif t == "number" then
        local plumeTable =vm.runtime.plume.table
        local locale = plumeTable.locale:get()
        local file = _GET_CURRENT_FILE(vm)

        if locale ~= vm.plume.obj.empty and locale ~= "none" and not file.flagRawNumbers then
            local success, result = vm.plume.formatNumber(
                value, 
                plumeTable.localeNumberFormat:get(),
                locale,
                plumeTable.localeThousandsSeparator:get(),
                plumeTable.localeDecimalSeparator:get(),
                plumeTable.localeThousandthsSeparator:get()
            )
    
            if success then
                _STACK_SET(vm, vm.mainStack, _STACK_POS(vm, vm.mainStack), result)
            else
                _ERROR(vm, result)
            end
        else
            _STACK_SET(vm, vm.mainStack, _STACK_POS(vm, vm.mainStack), tostring(value))
        end
    elseif t ~= "string" and t ~= "fragment" then
        local meta = t == "table" and value:getMetaItem("tostring")
        if  meta then
            _STACK_POP(vm, vm.mainStack)

            BEGIN_ACC(vm, 0, 0)
            _PUSH_SELF(vm, value)
            _STACK_PUSH(vm, vm.mainStack, meta)
            _INJECTION_PUSH(vm, vm.plume.ops.CONCAT_CALL, 0, 0)
        elseif t == "boolean" then
            _STACK_SET(vm, vm.mainStack, _STACK_POS(vm, vm.mainStack), tostring(value))
        else
            _ERROR (vm, vm.plume.error.cannotConcatValue(t))
        end
    end
end
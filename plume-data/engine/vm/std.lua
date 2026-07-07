--[[
This file is part of Plume🪶

Copyright © Erwan Barbedor
Licensed under the MIT License — see LICENSE for details.
]]


-- all STD_* should end by "_POP_CALLSTACK(vm)"

--- @param x any
--- @param t string
--- @raise an error if x
--! inline
function _ASSERT_STD_TYPE(vm, macroName, argPos, value, expected, signature)
    local t = _GET_TYPE(vm, value)
    if t ~= expected then
        if not vm.err then
            if t == "nil" then
                t = "empty"
            end
            _ERROR(vm, vm.plume.error.wrongArgTypeStd(
                argPos, macroName, t, expected, "$"..macroName.."("..signature..")"
            ))
        end
        return false
    end
    return true
end

--- @opcode
--! inline
function STD_LEN(vm, arg1, arg2)
	local t = _STACK_POP(vm, vm.mainStack).table[1]
	local tt = _GET_TYPE(vm, t)
    local result

	if tt == "table" then
        result = #t.table
    elseif tt == "string" then
        result = #t
    else
        _ERROR(vm, vm.plume.error.hasNoLen(tt))
    end

    --! to-remove-begin
    if not vm.err then -- only needed in dev mode, to prevent STACK_PUSH to crash
    --! to-remove-end
        _STACK_PUSH(vm, vm.mainStack, result)
    --! to-remove-begin
    end
    --! to-remove-end

    _POP_CALLSTACK(vm)
end

--- @opcode
--! inline
function STD_TYPE(vm, arg1, arg2)
    local t = _STACK_POP(vm, vm.mainStack).table[1]
    _STACK_PUSH(vm, vm.mainStack, _GET_TYPE(vm, t))

    _POP_CALLSTACK(vm)
end

--- @opcode
--! inline
function STD_SEQ(vm, arg1, arg2)
    local signature = "numbers stop|start, stop|start, stop, step"

    local args = _STACK_POP(vm, vm.mainStack).table
    local start = tonumber(args[1])
    local stop  = tonumber(args[2])
    local step  = tonumber(args[3] or 1)

    _ASSERT_STD_TYPE(vm, "seq", 1, start, "number", signature)

    if not stop then
        stop = start
        start = 1
    end
    
    _ASSERT_STD_TYPE(vm, "seq", 2, stop,  "number", signature)
    _ASSERT_STD_TYPE(vm, "seq", 3, step,  "number", signature)

    start = tonumber(start)
    stop = tonumber(stop)

    _STACK_PUSH(vm, vm.mainStack, {
        type = "stdIterator",
        start=start-step, --FOR_ITER increment state before using it
        stop=stop,
        step=step,
        flag = vm.flag.ITER_SEQ
    })

    _POP_CALLSTACK(vm)
end

--- @opcode
--! inline
function STD_ITEMS(vm, arg1, arg2)
    local args = _STACK_POP(vm, vm.mainStack).table
    
    _ASSERT_STD_TYPE(vm, "items", 1, args[1],  "table", "table t")

    _STACK_PUSH(vm, vm.mainStack, {
        type = "stdIterator",
        ref  = args[1],
        flag = vm.flag.ITER_ITEMS,
        named = args.named,
    })

    _POP_CALLSTACK(vm)
end

--- @opcode
--! inline
function STD_ENUMERATE(vm, arg1, arg2)
    local args = _STACK_POP(vm, vm.mainStack).table

    _ASSERT_STD_TYPE(vm, "enumerate", 1, args[1],  "table", "table t")

    _STACK_PUSH(vm, vm.mainStack, {
        type = "stdIterator",
        ref = args[1],
        flag = vm.flag.ITER_ENUMS
    })

    _POP_CALLSTACK(vm)
end

--- @opcode
--! inline
function STD_IMPORT(vm, arg1, arg2)
    local args = _STACK_POP(vm, vm.mainStack)

    local firstFilename = vm.runtime.files[1].name
    local lastFilename  = vm.runtime.files[vm.fileStack[vm.fileStack.pointer]].name
    local currentFile   = _GET_CURRENT_FILE(vm)

    local assertion = _ASSERT_STD_TYPE(vm, "import", 1, args.table[1],  "string", "string path, ...params")

    if assertion then
        local filename, searchPaths = vm.plume.getFilenameFromPath(
            args.table[1],
            false,
            vm.runtime,
            firstFilename,
            lastFilename
        )

        if filename then
            local success = true
            local err
            local chunk = vm.runtime.files[filename]
            if not chunk then
                chunk =  vm.plume.obj.macro(filename, vm.runtime)

                local f = io.open(filename)
                    local code = f:read("*a")
                f:close()
                success, err = pcall(vm.plume.compileFile, code, filename, chunk, vm.runtime)
                vm.runtime.files[filename] = chunk
            end
            if success then
                -- Save params for FILE_INIT_PARAMS
                vm.fileParams = {}

                if chunk.variadicParam then
                    table.insert(vm.fileParams, {
                        offset = chunk.variadicParam.offset,
                        key    = chunk.variadicParam.name,
                        value  = vm.plume.obj.table(0, 0)
                    })
                end

                for _, key in ipairs(args.keys) do
                    if key ~= 1 then
                        local value = args.table[key]
                        if tonumber(key) then
                            key = "arg" .. (key-1) -- 1 is the file path
                        end
                        local offset = chunk.namedParamOffset[key]
                        if offset and (not chunk.variadicParam or offset ~= chunk.variadicParam.offset) then
                            table.insert(vm.fileParams, {offset=offset, key=key, value=value})
                        elseif chunk.variadicParam then
                            local variadic = vm.fileParams[1].value
                            variadic:setItem(key, args.table[key])
                        elseif chunk.futureFlagUnknownParamError then
                            _ERROR(vm, vm.plume.error.unknownParamError(key, chunk.namedParamOffset))
                        else
                             vm.plume.warning.runtimeWarning(string.format("Unknown parameter `%s` for this file.\nFrom edition `raven`, this will lead to an error.", key), nil, vm.runtime, vm.ip, {886, 981})
                        end
                    end
                end

                local cacheId, paramMutableWarning = vm.plume.getModuleCacheId(filename, vm.fileParams)
                local result = vm.runtime.cache.results[cacheId]

                if result and currentFile.futureFlagImportCache then
                    _STACK_PUSH(vm, vm.mainStack, result)
                    if paramMutableWarning then
                        vm.plume.warning.runtimeWarning(string.format("Import call skipped (cached).\nAny modifications of the mutable parameter `%s` will be ignored.", paramMutableWarning), nil, vm.runtime, vm.ip, {890})
                    end
                else
                    chunk.cacheId = cacheId
                    -- prepare stack and jumps
                    _STACK_PUSH(vm, vm.fileStack, chunk.fileID)
                    _STACK_PUSH(vm, vm.macroStack, vm.ip + 1)
                    -- ENTER_SCOPE is already the first file instruction
                    _INJECTION_PUSH(vm, vm.plume.ops.JUMP, 0, chunk.offset)
                end
            else
                _ERROR(vm, err)
            end
        else
            _ERROR(vm, vm.plume.error.cannotOpenFile(args.table[1], searchPaths))
        end
    end

    -- No _POP_STACK, handled by RETURN_FILE
end
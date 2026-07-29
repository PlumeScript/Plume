--[[
This file is part of Plume🪶

Copyright © Erwan Barbedor
Licensed under the MIT License — see LICENSE for details.
]]

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
--- Import and execute another Plume file.
--- Compiles (or retrieves cached) the file, distributes its parameters,
--- pushes the fileID onto `fileStack`, and jumps to the file's code offset.
--- Results are cached by parameter identity for future imports.
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

                local code = futf8.read(filename)
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
                    if key ~= 1 and (chunk.futureFlagPositionnalFileParam or not tonumber(key)) then
                        local value = args.table[key]
                        local varKey
                        if tonumber(key) then
                            key = key-1-- 1 is the file path
                            varKey = "arg" .. key
                        else
                            varKey = key
                        end
                        local offset = chunk.namedParamOffset[varKey]
                        if offset and (not chunk.variadicParam or offset ~= chunk.variadicParam.offset) then
                            table.insert(vm.fileParams, {offset=offset, key=varKey, value=value})
                        elseif chunk.variadicParam then
                            local variadic = vm.fileParams[1].value
                            variadic:setItem(key, value)
                        elseif chunk.futureFlagUnknownParamError then
                            _ERROR(vm, vm.plume.error.unknownParamError(varKey, chunk.namedParamOffset))
                        else
                             vm.plume.warning.runtimeWarning(string.format("Unknown parameter `%s` for this file.\nFrom edition `raven`, this will lead to an error.", varKey), nil, vm.runtime, vm.ip, {886, 981})
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
                    JUMP(vm, 0, chunk.offset)
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
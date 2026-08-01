--[[
This file is part of Plume🪶

Copyright © Erwan Barbedor
Licensed under the MIT License — see LICENSE for details.
]]

return function(vm)
	--- @param x any
	--- @param t string
	--- @raise an error if x
	--! inline
	function vm:_ASSERT_STD_TYPE(macroName, argPos, value, expected, signature)
	    local t = self:_GET_TYPE(value)
	    if t ~= expected then
	        if not self.err then
	            if t == "nil" then
	                t = "empty"
	            end
	            self:_ERROR(self.plume.error.wrongArgTypeStd(
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
	function vm:STD_IMPORT(arg1, arg2)
	    local args = self:_STACK_POP(self.mainStack)

	    local firstFilename = self.runtime.files[1].name
	    local lastFilename  = self.runtime.files[self.fileStack[self.fileStack.pointer]].name
	    local currentFile   = self:_GET_CURRENT_FILE()

	    local assertion = self:_ASSERT_STD_TYPE("import", 1, args.table[1],  "string", "string path, ...params")

	    if assertion then
	        local filename, searchPaths = self.plume.getFilenameFromPath(
	            args.table[1],
	            false,
	            self.runtime,
	            firstFilename,
	            lastFilename
	        )

	        if filename then
	            local success = true
	            local err
	            local chunk = self.runtime.files[filename]
	            if not chunk then
	                chunk =  self.plume.obj.macro(filename, self.runtime)

	                local code = futf8.read(filename)
	                success, err = pcall(self.plume.compileFile, code, filename, chunk, self.runtime)
	                self.runtime.files[filename] = chunk
	            end
	            if success then
	            	self:_SAVE_SCALAR()
	            	local success, result = vm:initFileParams(chunk, args)
	            	self:_UPDATE_SCALAR()

	            	if not success then
	            		self:_ERROR(result)
	            	end
	            	
	                local cacheId, paramMutableWarning = self.plume.getModuleCacheId(filename, self.fileParams)
	                local result = self.runtime.cache.results[cacheId]

	                if result and currentFile.futureFlagImportCache then
						self:_STACK_PUSH(self.mainStack, result)
	                    if paramMutableWarning then
	                        self.plume.warning.runtimeWarning(string.format("Import call skipped (cached).\nAny modifications of the mutable parameter `%s` will be ignored.", paramMutableWarning), nil, self.runtime, self.ip, {890})
	                    end
	                else
	                    chunk.cacheId = cacheId
	                    
						self:_STACK_PUSH(self.fileStack, chunk.fileID)
						vm:_RUN_START(chunk.offset)
	                end
	            else
	                self:_ERROR(err)
	            end
	        else
	            self:_ERROR(self.plume.error.cannotOpenFile(args.table[1], searchPaths))
	        end
	    end

	    -- No _POP_STACK, handled by RETURN_FILE
	end
end

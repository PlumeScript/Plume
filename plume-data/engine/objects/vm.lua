--[[
This file is part of Plume🪶

Copyright © Erwan Barbedor
Licensed under the MIT License — see LICENSE for details.
]]

return function(plume)
	function plume.obj.vm(runtime)
		local vm = {
			--- to remove? ----
			plume      = plume,
			-------------------
			ip         = 0,
			tic        = 0,
			jump       = 0,
			fileParams = nil,

			runtime    = runtime,
			bytecode   = runtime.bytecode,
			constants  = runtime.constants,
			upvalueMap = table.new(2^10, 0),

			flag = {
				ITER_TABLE  = 0,
				ITER_SEQ    = 1,
				ITER_ITEMS  = 2,
				ITER_ENUMS  = 3,
				ITER_CUSTOM = 4
			}
		}

		-- Stacks
		vm.mainStack                = table.new(2^14, 0)
		vm.mainStack.frames         = table.new(2^8, 0)
		vm.mainStack.pointer        = 0
		vm.mainStack.frames.pointer = 0

		vm.variableStack                = table.new(2^10, 0)
		vm.variableStack.frames         = table.new(2^8, 0)
		vm.variableStack.pointer        = 0
		vm.variableStack.frames.pointer = 0
			
		vm.closureStack                 = table.new(2^8, 0)
		vm.closureStack.pointer         = 0

		vm.fileStack         = table.new(2^8, 0)
		vm.fileStack.pointer = 0

		vm.macroStack         = table.new(2^8, 0)
		vm.macroStack.pointer = 0

		vm.recursiveStack         = table.new(64, 0)
		vm.recursiveStack.pointer = 0

		vm.tagStack = table.new(2^14, 0)

		-- Context
		vm.runtime.localStack         = table.new(2^8, 0)
		vm.runtime.localStack.pointer = 0
		vm.contextStackCache          = table.new(2^8, 0)
		vm.contextStackCache.pointer  = 0

		-- opcodes & utils
		for _, loader in ipairs(plume.vmLoaders) do
			loader(vm)
		end

		for name in ("OP_BITS ARG1_BITS ARG2_BITS ARG1_SHIFT OP_SHIFT MASK_OP MASK_ARG1 MASK_ARG2"):gmatch('%S+') do
			vm[name] = plume[name]
		end

		function vm:initFileParams(chunk, initFileParams)
			local currentFile = self.runtime.files[chunk.fileID]

			self.fileParams = {}
			if chunk.variadicParam then
				table.insert(self.fileParams, {
					offset = chunk.variadicParam.offset,
	                key    = chunk.variadicParam.name,
					value  = self.plume.obj.table(0, 0)
				})
			end

			if initFileParams then
				for _, key in ipairs(initFileParams.keys) do
					if key ~= 1 and (currentFile.futureFlagPositionnalFileParam or not tonumber(key)) then
						local value = initFileParams.table[key]
						local varKey
						if tonumber(key) then
							key = key-1-- 1 is the file path
							varKey = "arg" .. key
						else
							varKey = key
						end

						local offset = chunk.namedParamOffset[varKey]
						if offset and (not chunk.variadicParam or offset ~= chunk.variadicParam.offset) then
							table.insert(self.fileParams, {offset=offset, key=varKey, value=value})
						elseif chunk.variadicParam then
							local variadic = self.fileParams[1].value
							variadic:setItem(key, value)
						elseif currentFile.futureFlagUnknownParamError then
							return false, self.plume.error.unknownParamError(varKey, chunk.namedParamOffset), 1
						else
							 self.plume.warning.runtimeWarning(string.format("Unknown parameter `%s` for this file.\nFrom edition `raven`, this will lead to an error.", varKey), nil, self.runtime, self.ip, {886, 981})
						end
					end
				end
			end

			return true
		end

		return vm
	end
end
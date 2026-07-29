--[[
This file is part of Plume🪶

Copyright © Erwan Barbedor
Licensed under the MIT License — see LICENSE for details.
]]

--================--
-- Initalization --
--===============--

return function(vm)
	--! inline
	function vm:_INIT_FILE_PARAM(fileID, initFileParams, variadicParam, namedParamOffset)
	    local currentFile = self.runtime.files[fileID]

	    self.fileParams = {}
	    if variadicParam then
	        table.insert(self.fileParams, {
	            offset = variadicParam.offset,
	            value  = self.plume.obj.table(0, 0)
	        })
	    end

	    if initFileParams then
	        for key, value in pairs(initFileParams) do
	            if key ~= 1 and (currentFile.futureFlagPositionnalFileParam or not tonumber(key)) then
	                local varKey
	                if tonumber(key) then
	                    key = key-1-- 1 is the file path
	                    varKey = "arg" .. key
	                else
	                    varKey = key
	                end

	                local offset = namedParamOffset[varKey]
	                if offset and (not variadicParam or offset ~= variadicParam.offset) then
	                    table.insert(self.fileParams, {offset=offset, value=value})
	                elseif variadicParam then
	                    local variadic = self.fileParams[1].value
	                    variadic:setItem(key, value)
	                elseif currentFile.futureFlagUnknownParamError then
	                    self:_ERROR(self.plume.error.unknownParamError(varKey, namedParamOffset))
	                    self:_ERROR(self.plume.error.unknownParamError(varKey, namedParamOffset)) -- dirty fix
	                else
	                     self.plume.warning.runtimeWarning(string.format("Unknown parameter `%s` for this file.\nFrom edition `raven`, this will lead to an error.", varKey), nil, self.runtime, self.ip, {886, 981})
	                end
	            end
	        end
	    end
	end

	--- Only to inject directive to engine-opt
	--! inline
	function vm:_VM_OPT_INIT()
	    --! index-to-inline vm.err vmerr
	    --! index-to-inline vm.errip vmerrip
	    --! index-to-inline vm.* *
	    --! index-to-inline mainStack.*
	    --! index-to-inline variableStack.*
	    --! index-to-inline mainStackFrames.*
	    --! index-to-inline variableStackFrames.*
	    --! index-to-inline fileStack.*
	    --! index-to-inline macroStack.*
	    --! index-to-inline injectionStack.*
	    --! index-to-inline contextStackCache.*
	    --! index-to-inline closureStack.*
	    --! index-to-inline flag.* *
	    --! index-to-inline runtime.*
	    --! index-to-inline plume.obj
	    --! index-to-inline plumeObj.*
	    --! index-to-inline plume._run_dev run
	    --! index-to-inline sops.* sops_*

	end

	--- Declare all vm variables
	--- @param runtime runtime The runtime to execute
	--! inline-nodo
	function vm:_VM_INIT(fileID)
	    --=====================--
	    -- Instruction format --
	    --=====================--
	    self.OP_BITS    = self.plume.OP_BITS
	    self.ARG1_BITS  = self.plume.ARG1_BITS
	    self.ARG2_BITS  = self.plume.ARG2_BITS
	    self.ARG1_SHIFT = self.ARG2_BITS
	    self.OP_SHIFT   = self.ARG1_BITS + self.ARG2_BITS
	    self.MASK_OP    = bit.lshift(1, self.OP_BITS) - 1
	    self.MASK_ARG1  = bit.lshift(1, self.ARG1_BITS) - 1
	    self.MASK_ARG2  = bit.lshift(1, self.ARG2_BITS) - 1
	    self.band       = bit.band
	    self.rshift     = bit.rshift
	    ---------------------------

	    if #self.fileStack == 0 then
	        self.fileStack[1] = fileID
	    end

	    --! to-remove-begin
	    if self.plume.runStatFlag then
	        self.stats = {}
	        self.stats.opseq = {} -- opcode sequences

	        -- queue for opcodes history
	        self.stats.ophist = 0
	        self.stats.histmask = 128^self.plume.runStatDeep
	    end
	    --! to-remove-end
	end

	--! to-remove-begin
	--- Register opcodes usages
	function vm:_STAT_REGISTER(op)
	    -- Update history
	    self.stats.ophist = ((self.stats.ophist % self.stats.histmask) * 128) + op
	    -- Update sequences
	    self.stats.opseq[self.stats.ophist] = 1 + (self.stats.opseq[self.stats.ophist] or 0)
	end
	--! to-remove-end

	--- Called at each instruction.
	--- Jump if needed and increment instruction counter
	--! inline-nodo
	function vm:_VM_TICK()
	    if self.jump>0 then
	        self.ip = self.jump
	        self:_RESET_JUMP()
	    else
	        self.ip = self.ip+1
	    end
	    self.tic = self.tic+1
	end

	--- Decoding opcode and arguments from instruction
	--! inline-nodo
	function vm:_VM_DECODE_CURRENT_INSTRUCTION()
	    local op, arg1, arg2
	    if self:_CAN_INJECT() then
	        op, arg1, arg2 = self:_INJECTION_POP()
	    else
	        self:_VM_TICK()
	        local instr = self.bytecode[self.ip]
	        op    = self.band(self.rshift(instr, self.OP_SHIFT), self.MASK_OP)
	        arg1  = self.band(self.rshift(instr, self.ARG1_SHIFT), self.MASK_ARG1)
	        arg2  = self.band(instr, self.MASK_ARG2)
	    end

	    --! to-remove-begin
	    if self.plume.hook then
	        self.plume.hook (self)
	    end
	    if self.plume.runStatFlag then
	        self:_STAT_REGISTER(op)
	    end
	    --! to-remove-end

	    return op, arg1, arg2
	end
end

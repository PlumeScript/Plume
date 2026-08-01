--[[
This file is part of Plume🪶

Copyright © Erwan Barbedor
Licensed under the MIT License — see LICENSE for details.
]]

--================--
-- Initalization --
--===============--

return function(vm)
	--- Declare all vm variables
	--- @param runtime runtime The runtime to execute
	--! inline-nodo
	function vm:_VM_INIT(fileID)
	    if #self.fileStack == 0 then
	        self.fileStack[1] = fileID
	    end

	    --! to-remove-begin
	    if self.plume.runStatFlag then
	        self.stats = {}
	        self.stats.opseq = {} -- opcode sequences
	        self.stats.ipcount = {} -- instruction count per ip

	        -- queue for opcodes history
	        self.stats.ophist = 0
	        self.stats.histmask = 128^self.plume.runStatDeep
	    end
	    --! to-remove-end
	end

	--- Register opcodes usages
	function vm:_STAT_REGISTER(op)
		--! to-remove-begin
	    -- Update history
	    self.stats.ophist = ((self.stats.ophist % self.stats.histmask) * 128) + op
	    -- Update sequences
	    self.stats.opseq[self.stats.ophist] = 1 + (self.stats.opseq[self.stats.ophist] or 0)
	    -- Update per-ip count
	    self.stats.ipcount[self.ip] = 1 + (self.stats.ipcount[self.ip] or 0)
	    --! to-remove-end
	end

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
	--! inline
	function vm:_VM_DECODE_CURRENT_INSTRUCTION()
	    local op, arg1, arg2
        self:_VM_TICK()
        local instr = self.bytecode[self.ip]
        op    = band(rshift(instr, self.OP_SHIFT), self.MASK_OP)
        arg1  = band(rshift(instr, self.ARG1_SHIFT), self.MASK_ARG1)
        arg2  = band(instr, self.MASK_ARG2)

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

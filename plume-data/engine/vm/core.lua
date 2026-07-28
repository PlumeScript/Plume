--[[
This file is part of Plume🪶

Copyright © Erwan Barbedor
Licensed under the MIT License — see LICENSE for details.
]]

--================--
-- Initalization --
--===============--

--! inline
function _INIT_FILE_PARAM(vm, fileID, initFileParams, variadicParam, namedParamOffset)
    local currentFile = vm.runtime.files[fileID]

    vm.fileParams = {}
    if variadicParam then
        table.insert(vm.fileParams, {
            offset = variadicParam.offset,
            value  = vm.plume.obj.table(0, 0)
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
                    table.insert(vm.fileParams, {offset=offset, value=value})
                elseif variadicParam then
                    local variadic = vm.fileParams[1].value
                    variadic:setItem(key, value)
                elseif currentFile.futureFlagUnknownParamError then
                    _ERROR(vm, vm.plume.error.unknownParamError(varKey, namedParamOffset))
                    _ERROR(vm, vm.plume.error.unknownParamError(varKey, namedParamOffset)) -- dirty fix
                else
                     vm.plume.warning.runtimeWarning(string.format("Unknown parameter `%s` for this file.\nFrom edition `raven`, this will lead to an error.", varKey), nil, vm.runtime, vm.ip, {886, 981})
                end
            end
        end
    end
end

--- Only to inject directive to engine-opt
--! inline
function _VM_OPT_INIT(vm)
    --! index-to-inline vm.err vmerr
    --! index-to-inline vm.serr vmserr
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
end

--- Declare all vm variables
--- @param runtime runtime The runtime to execute
--! inline-nodo
function _VM_INIT(vm, fileID)
    --=====================--
    -- Instruction format --
    --=====================--
    vm.OP_BITS    = vm.plume.OP_BITS
    vm.ARG1_BITS  = vm.plume.ARG1_BITS
    vm.ARG2_BITS  = vm.plume.ARG2_BITS
    vm.ARG1_SHIFT = vm.ARG2_BITS
    vm.OP_SHIFT   = vm.ARG1_BITS + vm.ARG2_BITS
    vm.MASK_OP    = bit.lshift(1, vm.OP_BITS) - 1
    vm.MASK_ARG1  = bit.lshift(1, vm.ARG1_BITS) - 1
    vm.MASK_ARG2  = bit.lshift(1, vm.ARG2_BITS) - 1
    vm.band       = bit.band
    vm.rshift     = bit.rshift
    ---------------------------

    if #vm.fileStack == 0 then
        vm.fileStack[1] = fileID
    end

    --! to-remove-begin
    if vm.plume.runStatFlag then
        vm.stats = {}
        vm.stats.opseq = {} -- opcode sequences
        
        -- queue for opcodes history
        vm.stats.ophist = 0
        vm.stats.histmask = 128^vm.plume.runStatDeep
    end
    --! to-remove-end
end

--! to-remove-begin
--- Register opcodes usages
function _STAT_REGISTER(vm, op)
    -- Update history
    vm.stats.ophist = ((vm.stats.ophist % vm.stats.histmask) * 128) + op
    -- Update sequences
    vm.stats.opseq[vm.stats.ophist] = 1 + (vm.stats.opseq[vm.stats.ophist] or 0)
end
--! to-remove-end

--- Called at each instruction.
--- Jump if needed and increment instruction counter
--! inline-nodo
function _VM_TICK (vm)
    if vm.jump>0 then
        vm.ip = vm.jump
        _RESET_JUMP(vm)
    else
        vm.ip = vm.ip+1
    end
    vm.tic = vm.tic+1
end

--- Decoding opcode and arguments from instruction
--! inline-nodo
function _VM_DECODE_CURRENT_INSTRUCTION(vm)
    local op, arg1, arg2
    if _CAN_INJECT(vm) then
        op, arg1, arg2 = _INJECTION_POP(vm)
    else    
        _VM_TICK(vm)
        local instr = vm.bytecode[vm.ip]
        op    = vm.band(vm.rshift(instr, vm.OP_SHIFT), vm.MASK_OP)
        arg1  = vm.band(vm.rshift(instr, vm.ARG1_SHIFT), vm.MASK_ARG1)
        arg2  = vm.band(instr, vm.MASK_ARG2)
    end

    --! to-remove-begin
    if vm.plume.hook then
        vm.plume.hook (vm)    
    end
    if vm.plume.runStatFlag then
        _STAT_REGISTER(vm, op)
    end
    --! to-remove-end

    return op, arg1, arg2
end
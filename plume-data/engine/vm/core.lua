--[[
This file is part of Plume🪶

Copyright © Erwan Barbedor
Licensed under the MIT License — see LICENSE for details.
]]

--================--
-- Initalization --
--===============--
--- Initiialize the VM
--- @param runtime runtime The runtime to execute
--! inline-nodo
function _VM_INIT (plume, runtime, chunk, initFileParams)
    local vm = {} --! to-remove
    
    -- to avoid context injection
    vm.plume = plume --! to-remove

    _VM_INIT_VARS(vm, runtime, chunk)

    -- Inject file params
    local currentFile = runtime.files[chunk.fileID]

    vm.fileParams = {}
    if chunk.variadicParam then
        table.insert(vm.fileParams, {
            offset = chunk.variadicParam.offset,
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

                local offset = chunk.namedParamOffset[varKey]
                if offset and (not chunk.variadicParam or offset ~= chunk.variadicParam.offset) then
                    table.insert(vm.fileParams, {offset=offset, value=value})
                elseif chunk.variadicParam then
                    local variadic = vm.fileParams[1].value
                    variadic:setItem(key, value)
                elseif currentFile.futureFlagUnknownParamError then
                    _ERROR(vm, vm.plume.error.unknownParamError(varKey, chunk.namedParamOffset))
                    _ERROR(vm, vm.plume.error.unknownParamError(varKey, chunk.namedParamOffset)) -- dirty fix
                else
                     vm.plume.warning.runtimeWarning(string.format("Unknown parameter `%s` for this file.\nFrom edition `raven`, this will lead to an error.", varKey), nil, vm.runtime, vm.ip, {886, 981})
                end
            end
        end
    end

    return vm --! to-remove
end

--- Declare all vm variables
--- @param runtime runtime The runtime to execute
--! inline-nodo
function _VM_INIT_VARS(vm, runtime, chunk)
    --! index-to-inline vm.err vmerr
    --! index-to-inline vm.serr vmserr
    --! index-to-inline vm.* *
    --! index-to-inline mainStack.*
    --! index-to-inline variableStack.*
    --! index-to-inline mainStackFrames.*
    --! index-to-inline variableStackFrames.*
    --! index-to-inline fileStack.*
    --! index-to-inline macroStack.*
    --! index-to-inline injectionStack.*
    --! index-to-inline contextStack.*
    --! index-to-inline flag.* *

    vm.runtime   = runtime
    vm.bytecode  = runtime.bytecode
    vm.constants = runtime.constants

    -- instruction pointer
    vm.ip      = chunk.offset - 1
    -- total instruction count
    vm.tic     = 0

    vm.mainStack                = table.new(2^14, 0)
    vm.mainStack.frames         = table.new(2^8, 0)
    vm.mainStack.pointer        = 0
    vm.mainStack.frames.pointer = 0

    vm.variableStack                = table.new(2^10, 0)
    vm.variableStack.frames         = table.new(2^8, 0)
    vm.variableStack.pointer        = 0
    vm.variableStack.frames.pointer = 0
    vm.upvalueMap                 = table.new(2^10, 0)

    vm.closureStack                 = table.new(2^8, 0)
    vm.closureStack.pointer         = 0

    vm.fileStack = table.new(2^8, 0)
    vm.fileStack[1] = chunk.fileID
    vm.fileStack.pointer = 1

    vm.macroStack = table.new(2^8, 0)
    vm.macroStack.pointer = 0

    vm.injectionStack         = table.new(64, 0)
    vm.injectionStack.pointer = 0

    vm.tagStack = table.new(2^14, 0)

    vm.fileParams = nil

    -- easier debuging than setting vm.ip
    vm.jump    = 0

    -- local variables
    vm.empty = vm.plume.obj.empty

    -- Context
    vm.runtime.localStack         = table.new(2^8, 0)
    vm.runtime.localStack.pointer = 0
    vm.globalStackCache          = vm.globalStackCache  or table.new(0, 2^8)
    vm.contextStackCache         = table.new(2^8, 0)
    vm.contextStackCache.pointer = 0

    -- flag
    vm.flag = {}
    vm.flag.ITER_TABLE  = 0
    vm.flag.ITER_SEQ    = 1
    vm.flag.ITER_ITEMS  = 2
    vm.flag.ITER_ENUMS  = 3
    vm.flag.ITER_CUSTOM = 4

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

--- Register opcodes usages
function _STAT_REGISTER(vm, op)
    -- Update history
    vm.stats.ophist = ((vm.stats.ophist % vm.stats.histmask) * 128) + op
    -- Update sequences
    vm.stats.opseq[vm.stats.ophist] = 1 + (vm.stats.opseq[vm.stats.ophist] or 0)
end

--- Called at each instruction.
--- Jump if needed and increment instruction counter
--! inline-nodo
function _VM_TICK (vm)
    if vm.jump>0 then
        vm.ip = vm.jump
        vm.jump = 0-- 0 instead of nil to preserve type
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
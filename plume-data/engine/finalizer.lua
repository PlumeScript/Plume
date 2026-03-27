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

return function (plume)
	local function insert(runtime)
		local offset = 0
		while offset < #runtime.instructions do
			offset = offset + 1
			instr = runtime.instructions[offset]
			local insert = runtime.insert[instr.label]
			if instr.label and insert then
				for _, newInstr in ipairs(insert) do
					offset = offset + 1
					table.insert(runtime.instructions, offset, newInstr)
				end
			end
		end
	end

	local function link(runtime)
		local bytecodeSize = runtime.bytecode and #runtime.bytecode or 0

		local labels = {}
		local removedCount = 0
		for offset=1, #runtime.instructions do
			instr = runtime.instructions[offset]
			if instr.label then
				labels[instr.label] = offset - removedCount
				removedCount = removedCount + 1
			end
		end

		local removedOffset = 0
		for offset=1, #runtime.instructions do
			instr = runtime.instructions[offset]
			offset = offset-removedOffset
			if instr.label then
				removedOffset = removedOffset + 1
				if instr.link then
					runtime.constants[instr.link].offset = bytecodeSize + offset --set macro offset
				end
			elseif instr._goto then
				if not labels[instr._goto] then
					error("Internal Error: no label " .. instr._goto)
				end

				runtime.linkedInstructions[offset] = {plume.ops[instr.jump], 0, bytecodeSize + labels[instr._goto]}
			else
				runtime.linkedInstructions[offset] = instr
			end
		end

		table.insert(runtime.linkedInstructions, {plume.ops.RETURN_FILE, 0, 0})
	end

	local function findNode(instructions, offset)
		local node
		while not node and offset>0 do
			node = instructions[offset].mapsto
			offset = offset - 1
		end
		return node
	end

	local function checkPartSize(instructions, offset, value, name, max)
	    if value > max then
	    	plume.error.instructionFieldOverflow(findNode(instructions, offset), name, value, max)
	    end
	end

    require"table.new"
    local bit = require("bit")
	local function encode(runtime)
		if not runtime.bytecode then
			runtime.bytecode = table.new(#runtime.linkedInstructions, 0)
		end
		local bytecodeSize = #runtime.bytecode
		local instructionsCount = #runtime.linkedInstructions

		if bytecodeSize + instructionsCount > plume.MASK_ARG2 then
			plume.error.toManyInstructions(findNode(runtime.linkedInstructions, instructionsCount), bytecodeSize + instructionsCount, plume.MASK_ARG2)
		end

		for offset=1, instructionsCount do
			instr = runtime.linkedInstructions[offset]

			checkPartSize(runtime.linkedInstructions, offset, instr[1], "OP",   2^plume.OP_BITS-1)
			checkPartSize(runtime.linkedInstructions, offset, instr[2], "ARG1", 2^plume.ARG1_BITS-1)
			checkPartSize(runtime.linkedInstructions, offset, instr[3], "ARG2", 2^plume.ARG2_BITS-1)

			local op_part = bit.lshift(bit.band(instr[1], plume.MASK_OP), plume.OP_SHIFT)
			local arg1_part = bit.lshift(bit.band(instr[2], plume.MASK_ARG1), plume.ARG1_SHIFT)
			local arg2_part = bit.band(instr[3], plume.MASK_ARG2)
			local byte = bit.bor(op_part, arg1_part, arg2_part)
			runtime.bytecode[bytecodeSize+offset] = byte
			runtime.mapping[bytecodeSize+offset] = instr.mapsto
		end
	end

	local function clean(runtime)
		runtime.instructions = {}
		runtime.linkedInstructions = {}
	end

	function plume.finalize(runtime)
		-- Proceed all insertion
		insert(runtime)
		-- replaces labels/goto by jumps
		-- compute real macro offsets
		-- Add "end" byte
		link(runtime)
		-- Encode instruction in one 32bits int
		encode(runtime)
		-- Clean temp table for next file
		clean(runtime)

		return true
	end
end
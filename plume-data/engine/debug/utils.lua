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
	local function escapeString(s, maxlength)

		if type(s) == "table" then
			if s == plume.obj.empty then
				s = "empty"
			elseif s.type == "macro" then
				s = "macro '" .. (s.name or "???") .. "'"
			elseif s.type == "luaFunction" then
				s = "luaFunction '" .. (s.name or "???") .. "'"
			end
		end

		s = tostring(s)
		s = s:gsub('\n', '\\n'):gsub('\t', '\\t')

		if #s >= (maxlength or 20)+5 then
			s = s:sub(1, maxlength or 20) .. '[...]'
		end

		if s:match('^%s+$') then
			s = '"' ..s .. '"'
		end

		return s
	end

	function plume.debug.invTable(t)
		local result = {}
		for k, v in pairs(t) do
			result[v] = k
		end
		return result
	end

	local function getConstantInfos(num, runtime)
		local obj = runtime.constants[num]
		if not obj then
			return
		end
		value = escapeString(obj, 30)

		return {value=value}
	end

	local OP_BITS   = 7
	local ARG1_BITS = 5
	local ARG2_BITS = 20
	local ARG1_SHIFT = ARG2_BITS
	local OP_SHIFT   = ARG1_BITS + ARG2_BITS
	local MASK_OP   = bit.lshift(1, OP_BITS) - 1
	local MASK_ARG1 = bit.lshift(1, ARG1_BITS) - 1
	local MASK_ARG2 = bit.lshift(1, ARG2_BITS) - 1
	local function getInstrInfos(instr, runtime)
		local op   = bit.band(bit.rshift(instr, OP_SHIFT), MASK_OP)
		local arg1 = bit.band(bit.rshift(instr, ARG1_SHIFT), MASK_ARG1)
		local arg2 = bit.band(instr, MASK_ARG2)

		local t = plume.debug.invTable(plume.ops)

		local name = plume.debug.invTable(plume.ops)[op] or "NULL"
		local constInfos
		local value
		constInfos = getConstantInfos(arg2, runtime)

		if ("LOAD_CONSTANT"):match(name) then
			value = constInfos.value
		elseif ("CALL OPP_CONCAT ESCAPE EVAL_SHORT STORE_LOCAL LOAD_LOCAL JUMP_IF ACC_CALL JUMP_IF_NOT_EMPTY JUMP ENTER_FILE"):match(name) then
			-- value = arg2
		elseif ("LOAD_LEXICAL STORE_LEXICAL ENTER_SCOPE"):match(name) then
			-- value = arg1 .. " " .. arg2
		end

		return {
			op = op,
			name = name,
			arg1 = arg1,
			arg2 = arg2,
			value = value
		}
	end

	function plume.debug.bytecodeGrid(runtime)
		local result = {}
		for ip, instr in ipairs(runtime.bytecode) do
			local infos = getInstrInfos(instr, runtime)
			local raw = string.format("%08X", instr)

			local node = runtime.mapping[ip]
			local content = ""
			if node and node.code then
				content = node.code:sub(node.bpos, node.epos)
				if content:match('\n') then
					content = content:match('^[^\n]*').."[...]"
				end
			end
			
			table.insert(result, {raw, infos.name, infos.arg1, infos.arg2, content})
		end
		return result
	end
end
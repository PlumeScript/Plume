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

return function(plume)
	require "table.new"
	
	plume.obj = {}
	plume.obj.empty = {type = "empty"}

	--- lua fonction take 1 parameter: the plume table of all given arguments
	function plume.obj.luaMacro (name, f)
		return {
			type = "luaMacro",
			callable = f,
			name = name -- optionnal
		}
	end

	function plume.obj.table (listSlots, hashSlots)
		local t
		t = {
			type = "table", --type
			table = table.new(listSlots, hashSlots),
			keys = table.new(hashSlots, 0),
			meta = {table={}}
		}
		return t
	end

	function plume.obj.macro(name, parent)
		local t = {
			type   = "macro",
			name   = name,
			positionalParamCount = 0,
			namedParamCount      = 0,
			namedParamOffset     = {},
			parent               = parent,
			isFile               = parent.type == "runtime",
			upvalues             = {} -- Variables that should be captured
			-- offset = offset -- Offset is set by the linker
		}

		if t.isFile then
			table.insert(parent.files, t)
			parent.files[name] = t
			t.fileID = #parent.files
		end
		
		return t
	end

	function plume.obj.runtime()
		return {
			type = "runtime",
			instructions         = {},
			insert               = {},
			linkedInstructions   = {},
			bytecode             = {},
			constants            = {},
			mapping              = {},
			callstack            = {},
			files                = {},
			env = {
				PLUME_PATH= os.getenv("PLUME_PATH")
			}
		}
	end

	local function reprTable(t, acc)
		acc[t] = true
		local result = {}
		for _, key in ipairs(t.keys) do
			local value = plume.repr(t.table[key], acc)

			if tonumber(key) then
				table.insert(result, value)
			else
				local key = plume.repr(key, acc)
				table.insert(result, string.format("%s: %s", key, value))
			end
		end

		return string.format("$table(%s)", table.concat(result, ", "))
	end

	function plume.repr(obj, acc)
		acc = acc or {}
		if type(obj) ~= "table" then
			return tostring(obj)
		end

		local t = obj.type
		if t == "empty" then
			return "empty"
		elseif t == "luaMacro" or t == "stdMacro" or t == "macro" then
			return t .. "<" .. obj.name .. ">"
		elseif t == "closure" then
			return "macro<" .. (obj.macro.name or "???") .. ">"
		elseif t == "table" then
			if acc[obj] then
				return "$table(...)"
			else
				return reprTable(obj, acc)
			end
		else
			return t.."Obj<"..(t.name or "???")..">"
		end
	end

end
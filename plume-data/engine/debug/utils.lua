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
	function plume.debug.exportAST(ast)
		local function exportAST(node)
			local result = {
				bpos = node.bpos,
				epos = node.epos,
				type = node.type,
				name = node.name,
				content = node.content,
			}
			if node.children then
				result.children = {}
				for _, child in pairs(node.children) do
					table.insert(result.children, exportAST(child))
				end
			end
			return result
		end
		return exportAST(ast)
	end

	function plume.debug.tojson(data)
		local function tojson(data, indent)
			indent = indent or ""
			local result = {}
			local first = true
			local isList = true
			for k, v in pairs(data) do
				if not tonumber(k) then
					isList = false
				end
			end

			for k, v in pairs(data) do
				if first then
					table.insert(result, "\n")
					first = false
				end

				table.insert(result, indent)
				if not isList then
					table.insert(result,  '"' .. k .. '":')
				end
				if type(v) == "table" then
					table.insert(result, tojson(v, indent .. "\t"))
				elseif type(v) == "string" then
					table.insert(result, '"' .. (v:gsub('"', '\\"'):gsub('\n', '\\n')) .. '"')
				else
					table.insert(result, v)
				end
				table.insert(result, ",\n")
			end
			
			if not first then
				table.remove(result)
				table.insert(result, "\n")
				table.insert(result, (indent:sub(1, -2)))
			end

			if isList then
				return "["..table.concat(result).."]"
			else
				return "{"..table.concat(result).."}"
			end
		end
		return tojson(data, "\t")
	end
end
-- --[[This file is part of Plume

-- Plume🪶 is free software: you can redistribute it and/or modify
-- it under the terms of the GNU General Public License as published by
-- the Free Software Foundation, version 3 of the License.

-- Plume🪶 is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
-- See the GNU General Public License for more details.

-- You should have received a copy of the GNU General Public License along with Plume🪶.
-- If not, see <https://www.gnu.org/licenses/>.
-- ]]

return function(plume)
	function plume.error.makeVisibleVariablesHint(node, name, visiblesVariables, includeConst)
		local variablesNames = {}
		for k, v in pairs(visiblesVariables) do
			if includeConst or not v.isConst then
				table.insert(variablesNames, k)
			end
		end

		local related = plume.error.suggestIdentifiers(name, variablesNames, 2, 3)

		if #related == 0 then
			return ""
		else
			for _, name in ipairs(related) do
				plume.error.addContext(node, visiblesVariables[name].node)
			end

			return string.format("\nPerhaps you mean '%s'?", table.concat( related, "', '"):gsub(', ([^,]-)$', ' or %1'))
		end
	end

	function plume.error.makeVisibleKeysHint(key, rawKeys)
		local keys = {}
		for _, key in ipairs(rawKeys) do
			if not tonumber(key) then
				table.insert(keys, key)
			end
		end
		local related = plume.error.suggestIdentifiers(key, keys, 2, 3)

		if #related == 0 then
			return ""
		else
			return string.format("\nPerhaps you mean '%s'?", table.concat( related, "', '"):gsub(', ([^,]-)$', ' or %1'))
		end
	end

	function plume.error.getSourceCode(node, size)
		local size = size or 10
		if node then
			local result = node.code:sub(node.bpos, node.epos):gsub('^%s*', ''):gsub('%s*$', '')
			if #result > size then
				result = result:sub(1, size-3) .. "..."
			end
			return result
		else
			return "[value]"
		end
	end
end
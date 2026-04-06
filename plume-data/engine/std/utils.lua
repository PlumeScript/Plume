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
	function plume.stdArgsCheck(name, args, signature)
		local argsCount = signature.args
		local minArgsCount = signature.minArgs or argsCount
		local maxArgsCount = signature.maxArgs or argsCount
		
		if minArgsCount or maxArgsCount then
			if (minArgsCount and #args.table < minArgsCount) or (maxArgsCount and #args.table > maxArgsCount) then
				return false, plume.error.wrongArgsCountStd(
					name, #args.table, minArgsCount, maxArgsCount, signature.signature
					
				)
			end
		end

		if signature.checkTypes or signature.named then
			for key, value in pairs(args.table) do
				if not tonumber(key)
				and (not signature.named      or (not signature.named[key] and not signature.named["*"]))
				and (not signature.checkTypes or not signature.checkTypes[key]) then
					return false, plume.error.unknownParameterStd(key, name, signature.signature)
				end
				local exectedType = signature.checkTypes and signature.checkTypes[key]
				if exectedType then
					local t = type(value)
					if t == "table" then
						t = value.type or "table"
					end
					if exectedType == "string" and t == "number" then
						t = "string"
						args.table[key] = tostring(value)
					elseif exectedType == "number" and t == "string" and tonumber(value) then
						t = "number"
						args.table[key] = tonumber(value)
					end

					if t == "table" then
						t = t.type or t
					end

					if exectedType ~= t then
						return false, plume.error.wrongArgTypeStd(key, name, t, exectedType, signature.signature)
					end
				end
			end
		end

		return true
	end
end
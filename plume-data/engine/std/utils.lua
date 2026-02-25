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
		
		if minArgsCount and maxArgsCount then
			if #args.table < minArgsCount or #args.table > maxArgsCount then
				return false, plume.error.wrongArgsCountStd(
					name, #args.table, minArgsCount, maxArgsCount, signature.signature
					
				)
			end
		end

		if signature.checkTypes or signature.named then
			for _, key in ipairs(args.keys) do
				if not tonumber(key)
				and (not signature.named      or not signature.named[key])
				and (not signature.checkTypes or not signature.checkTypes[name]) then
					return false, plume.error.unknownParameterStd(key, name, signature.signature)
				end

				local exectedType = signature.checkTypes and signature.checkTypes[key]
				if exectedType then
					local value = args.table[key]
					local t = type(value)
					if t == "table" then
						t = t.type or t
					end
					if exectedType ~= t then
						return false, plume.error.WrongArgTypeStd(key, name, t, exectedType, signature.signature)
					end
				end
			end
		end

		return true
	end
end
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
	local Number = plume.obj.table (0, 6)

	Number.table.keys = {
		"floor", "ceil", "round", "clamp", "format",
		"sign"
	}

	-- Manipulations
	Number.table.floor = plume.obj.luaFunction("floor", function (args)
		local x = plume.shiftArgs(Number, args)
		local digit = tonumber(args.table.digit or 0)
		return math.floor(x*10^digit)*10^-digit
	end)
	Number.table.ceil = plume.obj.luaFunction("ceil", function (args)
		local x = plume.shiftArgs(Number, args)
		local digit = tonumber(args.table.digit or 0)
		return math.ceil(x*10^digit)*10^-digit
	end)
	Number.table.round = plume.obj.luaFunction("round", function (args)
		local x = plume.shiftArgs(Number, args)
		local digit = tonumber(args.table.digit or 0)
		return math.floor(x*10^digit + 0.5)*10^-digit
	end)
	Number.table.clamp = plume.obj.luaFunction("clamp", function (args)
		local x, min, max = plume.shiftArgs(Number, args)
		return math.min(max, math.max(min, x))
	end)
	Number.table.format = plume.obj.luaFunction("format", function (args)
		local x, format = plume.shiftArgs(Number, args)
		local result = string.format(format, x)

		local _loc = args.table["local"]
		if _loc then
			local int, dec
			if result:gmatch('%.') then
				int = result:match('^[^%.]+')
				dec = result:match('%.([^%.]+)')
			else
				int = result
			end

			local int_sep, sep, dec_sep
			if _loc == "en" or _loc == "us" then
				int_sep = ","
				sep = "."
			elseif _loc == "fr" then
				int_sep = " "
				sep = ","
				dec_sep = " "
			else
				error("Unknow localization format '" .. _loc .. "'.")
			end

			int = int:gsub("(.)(...)$", "%1"..int_sep.."%2")
			for i=1, #int do
				int = int:gsub("([0-9])([0-9][0-9][0-9])[%"..int_sep.."]", "%1"..int_sep.."%2"..int_sep)
			end
			result = int

			if dec then
				if dec_sep then
					dec = dec:gsub("^([0-9][0-9][0-9])([0-9])", "%1"..dec_sep.."%2")
					for i=1, #int do
						dec = dec:gsub("[%"..dec_sep.."]([0-9][0-9][0-9])([0-9])", "%1"..dec_sep.."%2"..dec_sep)
					end
				end

				result = int ..sep .. dec
			end
		end

		return result
	end)

	-- Test
	Number.table.sign = plume.obj.luaFunction("sign", function (args)
		local x = plume.shiftArgs(Number, args)
		if x>0 then
			return 1
		elseif x<0 then
			return -1
		else
			return 0
		end
	end)

	Number.meta.table.call = plume.obj.luaFunction("Number", function(args)
		local x = args.table[1]
		if x == plume.obj.empty then
			error("Cannot convert empty into number", 0)
		elseif type(x) == "number" then
			return x
		elseif tonumber(x) then
			return tonumber(x)
		else
		   error(string.format("Cannot convert %s into number", type(x)), 0)
		end
	end)
	
	plume.std.Number = Number
end
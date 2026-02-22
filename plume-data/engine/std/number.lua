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
	local Number = plume.obj.table (0, 7)

	Number.table.keys = {
		"floor", "ceil", "round", "clamp", "format", "localize",
		"sign"
	}

	-- Manipulations
	Number.table.floor = plume.obj.luaMacro("floor", function (args)
		local x = plume.shiftArgs(Number, args)
		local digit = tonumber(args.table.digit or 0)
		return math.floor(x*10^digit)*10^-digit
	end)
	Number.table.ceil = plume.obj.luaMacro("ceil", function (args)
		local x = plume.shiftArgs(Number, args)
		local digit = tonumber(args.table.digit or 0)
		return math.ceil(x*10^digit)*10^-digit
	end)
	Number.table.round = plume.obj.luaMacro("round", function (args)
		local x = plume.shiftArgs(Number, args)
		local digit = tonumber(args.table.digit or 0)
		return math.floor(x*10^digit + 0.5)*10^-digit
	end)
	Number.table.clamp = plume.obj.luaMacro("clamp", function (args)
		local x, min, max = plume.shiftArgs(Number, args)
		return math.min(max, math.max(min, x))
	end)

	plume.formatNumber = function(x, format, locale, thousandsSeparator, decimalSeparator, thousandthsSeparator)
		if thousandsSeparator == plume.obj.empty then
			thousandsSeparator = nil
		end
		if thousandthsSeparator == plume.obj.empty then
			thousandthsSeparator = nil
		end
		if not format or format == plume.obj.empty then
			format = "%s"
		end

		local result = string.format(format, x)
		if locale then
			local integerPart, decimalPart
			if result:gmatch('%.') then
				integerPart = result:match('^[^%.]+')
				decimalPart = result:match('%.([^%.]+)')
			else
				integerPart = result
			end

			if locale == "en" or locale == "us" then
				thousandsSeparator = ","
				decimalSeparator  = "."
			elseif locale == "fr" then
				thousandsSeparator    = " "
				decimalSeparator     = ","
				thousandthsSeparator = " "
			elseif locale == "custom" then
				thousandsSeparator    = thousandsSeparator or nil
				decimalSeparator     = decimalSeparator or "."
				thousandthsSeparator = thousandthsSeparator or nil
			elseif locale then
				error("Unknow localization format '" .. locale .. "'.")
			end

			if thousandsSeparator then
				thousandsSeparator = thousandsSeparator:gsub("[%(%)%.%%%+%-%*%?%[%]%^%$]", "%%%1")
				integerPart = integerPart:gsub("(.)(...)$", "%1"..thousandsSeparator.."%2")
				for i=1, #integerPart do
					integerPart = integerPart:gsub("([0-9])([0-9][0-9][0-9])"..thousandsSeparator, "%1"..thousandsSeparator.."%2"..thousandsSeparator)
				end
			end
			result = integerPart

			if decimalPart then
				if thousandthsSeparator then
					thousandthsSeparator = thousandthsSeparator:gsub("[%(%)%.%%%+%-%*%?%[%]%^%$]", "%%%1")
					decimalPart = decimalPart:gsub("^([0-9][0-9][0-9])([0-9])", "%1"..thousandthsSeparator.."%2")
					for i=1, #integerPart do
						decimalPart = decimalPart:gsub(thousandthsSeparator.."([0-9][0-9][0-9])([0-9])", "%1"..thousandthsSeparator.."%2"..thousandthsSeparator)
					end
				end

				result = result .. decimalSeparator .. decimalPart
			end
		end
		return result
	end

	Number.table.format = plume.obj.luaMacro("format", function (args)
		local x, format = plume.shiftArgs(Number, args)
		local localTag             = args.table["locale"]
		local thousandsSeparator    = args.table["thousandsSeparator"]
		local decimalSeparator     = args.table["decimalSeparator"]
		local thousandthsSeparator = args.table["thousandthsSeparator"]

		return plume.formatNumber(x, format, localTag, thousandsSeparator, decimalSeparator, thousandthsSeparator)
	end)

	Number.table.localize = plume.obj.luaMacro("localize", function (args)
		local x, localTag = plume.shiftArgs(Number, args)

		return plume.formatNumber(x, "%s", localTag)
	end)

	-- Test
	Number.table.sign = plume.obj.luaMacro("sign", function (args)
		local x = plume.shiftArgs(Number, args)
		if x>0 then
			return 1
		elseif x<0 then
			return -1
		else
			return 0
		end
	end)

	Number.meta.table.call = plume.obj.luaMacro("Number", function(args)
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